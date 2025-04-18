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

  private
    def call_and_return_body(&block)
      app = block || proc { [200, {}, []] }
      env = Rack::MockRequest.env_for("", {})
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
