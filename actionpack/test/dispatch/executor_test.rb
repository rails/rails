# frozen_string_literal: true

require "abstract_unit"

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

  def test_returned_body_object_behaves_like_underlying_object
    body = call_and_return_body do
      b = MyBody.new
      b << "hello"
      b << "world"
      [200, { "Content-Type" => "text/html" }, b]
    end
    assert_equal 2, body.size
    assert_equal "hello", body[0]
    assert_equal "world", body[1]
    assert_equal "foo", body.foo
    assert_equal "bar", body.bar
  end

  def test_it_calls_close_on_underlying_object_when_close_is_called_on_body
    close_called = false
    body = call_and_return_body do
      b = MyBody.new do
        close_called = true
      end
      [200, { "Content-Type" => "text/html" }, b]
    end
    body.close
    assert close_called
  end

  def test_returned_body_object_responds_to_all_methods_supported_by_underlying_object
    body = call_and_return_body do
      [200, { "Content-Type" => "text/html" }, MyBody.new]
    end
    assert_respond_to body, :size
    assert_respond_to body, :each
    assert_respond_to body, :foo
    assert_respond_to body, :bar
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

    stack = middleware(proc { [200, {}, "response"] })

    requests_count = 5

    requests_count.times do
      stack.call({})
    end

    assert_equal (requests_count * 2) - 1, total
    assert_equal requests_count, ran
    assert_equal requests_count - 1, completed
  end

  def test_error_reporting
    raised_error = nil
    error_report = assert_error_reported(executor) do
      raised_error = assert_raises TypeError do
        call_and_return_body { 1 + "1" }
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
    error_report = assert_error_reported(executor) do
      middleware.call(env)
    end
    assert_instance_of TypeError, error_report.error
  end

  class BusinessAsUsual < StandardError; end

  def test_handled_error_is_not_reported
    old_rescue_responses = ActionDispatch::ExceptionWrapper.rescue_responses
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

    ActionDispatch::ExceptionWrapper.rescue_responses = { BusinessAsUsual.name => 418 }

    assert_no_error_reported(executor) do
      response = middleware.call(env)
      assert_equal 418, response[0]
    end
  ensure
    ActionDispatch::ExceptionWrapper.rescue_responses = old_rescue_responses
  end

  private
    def call_and_return_body(&block)
      app = middleware(block || proc { [200, {}, "response"] })
      _, _, body = app.call("rack.input" => StringIO.new(""))
      body
    end

    def middleware(inner_app)
      ActionDispatch::Executor.new(inner_app, executor)
    end

    def executor
      @executor ||= Class.new(ActiveSupport::Executor)
    end

    class ErrorCollector
      Report = Struct.new(:error, :handled, :severity, :context, :source, keyword_init: true)
      class Report
        alias_method :handled?, :handled
      end

      def record(executor)
        subscribe(executor)
        recorders = ActiveSupport::IsolatedExecutionState[:active_support_error_reporter_assertions] ||= []
        reports = []
        recorders << reports
        begin
          yield
          reports
        ensure
          recorders.delete_if { |r| reports.equal?(r) }
        end
      end

      def report(error, **kwargs)
        report = Report.new(error: error, **kwargs)
        ActiveSupport::IsolatedExecutionState[:active_support_error_reporter_assertions]&.each do |reports|
          reports << report
        end
        true
      end

      private
        def subscribe(executor)
          return if @subscribed

          if executor.error_reporter
            executor.error_reporter.subscribe(self)
            @subscribed = true
          else
            raise Minitest::Assertion, "No error reporter is configured"
          end
        end
    end

    def assert_no_error_reported(executor, &block)
      reports = ErrorCollector.new.record(executor) do
        _assert_nothing_raised_or_warn("assert_no_error_reported", &block)
      end
      assert_predicate(reports, :empty?)
    end

    def assert_error_reported(error_class = StandardError, executor, &block)
      reports = ErrorCollector.new.record(executor) do
        _assert_nothing_raised_or_warn("assert_error_reported", &block)
      end

      if reports.empty?
        assert(false, "Expected a #{error_class.name} to be reported, but there were no errors reported.")
      elsif (report = reports.find { |r| error_class === r.error })
        self.assertions += 1
        report
      else
        message = "Expected a #{error_class.name} to be reported, but none of the " \
          "#{reports.size} reported errors matched:  \n" \
          "#{reports.map { |r| r.error.class.name }.join("\n  ")}"
        assert(false, message)
      end
    end
end
