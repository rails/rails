# frozen_string_literal: true

require "abstract_unit"

class ReportErrorsTest < ActionDispatch::IntegrationTest
  class ErrorSubscriber
    def report(error, handled:, severity:, context:, source: nil)
    end
  end

  class TestApp
    def call(env)
      req = ActionDispatch::Request.new(env)
      raise StandardError.new("ruh roh")
    end
  end

  def setup
    @app = build_app
    executor.error_reporter.subscribe(ErrorSubscriber.new)
  end

  test "reports error" do
    report = assert_error_reported(StandardError) do
      begin
        get "/"
      rescue StandardError
      end
    end

    assert_equal "ruh roh", report.error.message
    assert_equal :error, report.severity
    assert_equal "application.action_dispatch", report.source
  end

  test "reports error with production like middleware" do
    stack = ActionDispatch::MiddlewareStack.new
    stack.use ActionDispatch::Executor, executor
    stack.use ActionDispatch::ShowExceptions, ActionDispatch::PublicExceptions.new("/public")
    stack.use ActionDispatch::DebugExceptions, Rack::Lint.new([]), "html"
    stack.use ActionDispatch::ReportErrors, executor

    app = Rack::Lint.new(
      stack.build(Rack::Lint.new(proc { |env| raise StandardError.new("ruh roh") }))
    )

    env = Rack::MockRequest.env_for("", {})
    report = assert_error_reported(StandardError) do
      begin
        app.call(env)
      rescue StandardError
      end
    end
    assert_equal "ruh roh", report.error.message
  end

  private

    def executor
      @executor ||= Class.new(ActiveSupport::Executor)
    end

    def build_app(exceptions_app = nil)
      Rack::Lint.new(ActionDispatch::ReportErrors.new(Rack::Lint.new(TestApp.new), executor))
    end
end
