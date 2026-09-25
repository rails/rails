# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/object/with"

class ExecutorTest < ActiveSupport::TestCase
  class MyBody < Array
    def initialize(&block)
      @on_close = block
    end

    def foo
      "foo"
    end

    def bar
      "bar"
    end

    def close
      @on_close.call if @on_close
    end
  end

  def test_returned_body_object_always_responds_to_close
    body = call_and_return_body
    assert_respond_to body, :close
  end

  def test_returned_body_object_always_responds_to_close_even_if_called_twice
    body = call_and_return_body
    assert_respond_to body, :close
    body.close

    body = call_and_return_body
    assert_respond_to body, :close
    body.close
  end

  def test_it_calls_close_on_underlying_object_when_close_is_called_on_body
    close_called = false
    body = call_and_return_body do
      b = MyBody.new do
        close_called = true
      end
      [200, { "content-type" => "text/html" }, b]
    end
    body.close
    assert close_called
  end

  def test_run_callbacks_are_called_before_close
    running = false
    executor.to_run { running = true }

    body = call_and_return_body
    assert running

    running = false
    body.close
    assert_not running
  end

  def test_complete_callbacks_are_called_on_close
    completed = false
    executor.to_complete { completed = true }

    body = call_and_return_body
    assert_not completed

    body.close
    assert completed
  end

  def test_complete_callbacks_are_called_on_exceptions
    completed = false
    executor.to_complete { completed = true }

    begin
      call_and_return_body do
        raise "error"
      end
    rescue
    end

    assert completed
  end

  def test_callbacks_execute_in_shared_context
    result = false
    executor.to_run { @in_shared_context = true }
    executor.to_complete { result = @in_shared_context }

    call_and_return_body.close
    assert result
    assert_not defined?(@in_shared_context) # it's not in the test itself
  end

  def test_body_abandoned
    total = 0
    ran = 0
    completed = 0

    executor.to_run { total += 1; ran += 1 }
    executor.to_complete { total += 1; completed += 1 }

    app = proc { [200, {}, []] }
    env = Rack::MockRequest.env_for("", {})

    stack = middleware(app)

    requests_count = 5

    requests_count.times do
      stack.call(env)
    end

    assert_equal (requests_count * 2) - 1, total
    assert_equal requests_count, ran
    assert_equal requests_count - 1, completed
  end

  def test_error_reporting
    raised_error = nil
    error_report = assert_error_reported(Exception) do
      raised_error = assert_raises Exception do
        call_and_return_body { raise Exception }
      end
    end
    assert_same raised_error, error_report.error
  end

  def test_error_reporting_with_show_exception
    middleware = Rack::Lint.new(
      ActionDispatch::Executor.new(
        ActionDispatch::ShowExceptions.new(
          Rack::Lint.new(->(_env) { 1 + "1" }),
          ->(_env) { [500, {}, ["Oops"]] },
        ),
        executor,
      )
    )

    env = Rack::MockRequest.env_for("", {})
    error_report = assert_error_reported do
      middleware.call(env)
    end
    assert_instance_of TypeError, error_report.error
  end

  class BusinessAsUsual < StandardError; end

  def test_handled_error_is_not_reported
    middleware = Rack::Lint.new(
      ActionDispatch::Executor.new(
        ActionDispatch::ShowExceptions.new(
          Rack::Lint.new(->(_env) { raise BusinessAsUsual }),
          ->(env) { [418, {}, ["I'm a teapot"]] },
        ),
        executor,
      )
    )

    env = Rack::MockRequest.env_for("", {})
    ActionDispatch::ExceptionWrapper.with(rescue_responses: { BusinessAsUsual.name => 418 }) do
      assert_no_error_reported do
        response = middleware.call(env)
        assert_equal 418, response[0]
      end
    end
  end

  def test_complete_callbacks_are_called_on_rack_response_finished
    completed = false
    executor.to_complete { completed = true }

    env = Rack::MockRequest.env_for
    env["rack.response_finished"] = []

    call_and_return_body(env)

    assert_not completed

    assert_equal 1, env["rack.response_finished"].size
    env["rack.response_finished"].first.call(env, 200, {}, nil)

    assert completed
  end

  def test_complete_callbacks_are_called_once_on_rack_response_finished_when_exception_is_raised
    completed_count = 0
    executor.to_complete { completed_count += 1 }

    env = Rack::MockRequest.env_for
    env["rack.response_finished"] = []

    begin
      call_and_return_body(env) do
        raise "error"
      end
    rescue
    end

    assert_equal 1, env["rack.response_finished"].size
    env["rack.response_finished"].first.call(env, 200, {}, nil)

    assert_equal 1, completed_count
  end

  def test_complete_runs_eagerly_on_websocket_upgrade
    completed = false
    executor.to_complete { completed = true }

    app = proc { [101, { "upgrade" => "websocket", "connection" => "upgrade" }, []] }
    env = Rack::MockRequest.env_for

    status, _, body = unlinted_middleware(app).call(env)

    assert_equal 101, status
    assert completed, "executor state should be completed eagerly on WebSocket upgrade rather than waiting for body close"

    body.close if body.respond_to?(:close)
  end

  def test_complete_runs_eagerly_on_full_rack_hijack
    completed = false
    executor.to_complete { completed = true }

    hijack_io = IO.pipe.first
    app = proc do |hijack_env|
      hijack_env["rack.hijack_io"] = hijack_io
      [200, {}, []]
    end
    env = Rack::MockRequest.env_for

    unlinted_middleware(app).call(env)

    assert completed, "executor state should be completed eagerly when the app installs rack.hijack_io"
  ensure
    hijack_io&.close
  end

  def test_complete_runs_once_when_hijack_response_also_registers_response_finished
    completed_count = 0
    executor.to_complete { completed_count += 1 }

    app = proc { [101, { "upgrade" => "websocket", "connection" => "upgrade" }, []] }
    env = Rack::MockRequest.env_for
    env["rack.response_finished"] = []

    unlinted_middleware(app).call(env)

    assert_equal 1, completed_count, "eager hijack completion should mark the executor done"

    env["rack.response_finished"].each { |cb| cb.call(env, 101, {}, nil) }

    assert_equal 1, completed_count, "the response_finished callback must not run a second complete!"
  end

  private
    def unlinted_middleware(inner_app)
      ActionDispatch::Executor.new(inner_app, executor)
    end

    def call_and_return_body(env = Rack::MockRequest.env_for, &block)
      app = block || proc { [200, {}, []] }
      _, _, body = middleware(app).call(env)
      body
    end

    def middleware(inner_app)
      Rack::Lint.new(ActionDispatch::Executor.new(Rack::Lint.new(inner_app), executor))
    end

    def executor
      @executor ||= Class.new(ActiveSupport::Executor)
    end
end
