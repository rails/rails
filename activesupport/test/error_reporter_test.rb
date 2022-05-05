# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/execution_context/test_helper"

class ErrorReporterTest < ActiveSupport::TestCase
  # ExecutionContext is automatically reset in Rails app via executor hooks set in railtie
  # But not in Active Support's own test suite.
  include ActiveSupport::ExecutionContext::TestHelper

  class ErrorSubscriber
    attr_reader :events

    def initialize
      @events = []
    end

    def report(error, handled:, severity:, source:, context:)
      @events << [error, handled, severity, source, context]
    end
  end

  setup do
    @reporter = ActiveSupport::ErrorReporter.new
    @subscriber = ErrorSubscriber.new
    @reporter.subscribe(@subscriber)
    @error = ArgumentError.new("Oops")
  end

  test "receives the execution context" do
    @reporter.set_context(section: "admin")
    error = ArgumentError.new("Oops")
    @reporter.report(error, handled: true)
    assert_equal [[error, true, :warning, "application", { section: "admin" }]], @subscriber.events
  end

  test "passed context has priority over the execution context" do
    @reporter.set_context(section: "admin")
    error = ArgumentError.new("Oops")
    @reporter.report(error, handled: true, context: { section: "public" })
    assert_equal [[error, true, :warning, "application", { section: "public" }]], @subscriber.events
  end

  test "passed source is forwarded" do
    error = ArgumentError.new("Oops")
    @reporter.report(error, handled: true, source: "my_gem")
    assert_equal [[error, true, :warning, "my_gem", {}]], @subscriber.events
  end

  test "#disable allow to skip a subscriber" do
    @reporter.disable(@subscriber) do
      @reporter.report(ArgumentError.new("Oops"), handled: true)
    end
    assert_equal [], @subscriber.events
  end

  test "#disable allow to skip a subscribers per class" do
    @reporter.disable(ErrorSubscriber) do
      @reporter.report(ArgumentError.new("Oops"), handled: true)
    end
    assert_equal [], @subscriber.events
  end

  test "#handle swallow and report any unhandled error" do
    error = ArgumentError.new("Oops")
    @reporter.handle do
      raise error
    end
    assert_equal [[error, true, :warning, "application", {}]], @subscriber.events
  end

  test "#handle can be scoped to an exception class" do
    assert_raises ArgumentError do
      @reporter.handle(NameError) do
        raise ArgumentError
      end
    end
    assert_equal [], @subscriber.events
  end

  test "#handle passes through the return value" do
    result = @reporter.handle do
      2 + 2
    end
    assert_equal 4, result
  end

  test "#handle returns nil on handled raise" do
    result = @reporter.handle do
      raise StandardError
      2 + 2
    end
    assert_nil result
  end

  test "#handle returns the value of the fallback as a proc on handled raise" do
    result = @reporter.handle(fallback: -> { 2 + 2 }) do
      raise StandardError
    end
    assert_equal 4, result
  end

  test "#handle raises if the fallback is not a callable" do
    assert_raises NoMethodError do
      @reporter.handle(fallback: "four") do
        raise StandardError
      end
    end
  end

  test "#handle raises the error up if fallback is a proc that then also raises" do
    assert_raises ArgumentError do
      @reporter.handle(fallback: -> { raise ArgumentError }) do
        raise StandardError
      end
    end
  end

  test "#record report any unhandled error and re-raise them" do
    error = ArgumentError.new("Oops")
    assert_raises ArgumentError do
      @reporter.record do
        raise error
      end
    end
    assert_equal [[error, false, :error, "application", {}]], @subscriber.events
  end

  test "#record can be scoped to an exception class" do
    assert_raises ArgumentError do
      @reporter.record(NameError) do
        raise ArgumentError
      end
    end
    assert_equal [], @subscriber.events
  end

  test "#record passes through the return value" do
    result = @reporter.record do
      2 + 2
    end
    assert_equal 4, result
  end

  test "can have multiple subscribers" do
    second_subscriber = ErrorSubscriber.new
    @reporter.subscribe(second_subscriber)

    error = ArgumentError.new("Oops")
    @reporter.report(error, handled: true)

    assert_equal 1, @subscriber.events.size
    assert_equal 1, second_subscriber.events.size
  end

  test "handled errors default to :warning severity" do
    @reporter.report(@error, handled: true)
    assert_equal :warning, @subscriber.events.dig(0, 2)
  end

  test "unhandled errors default to :error severity" do
    @reporter.report(@error, handled: false)
    assert_equal :error, @subscriber.events.dig(0, 2)
  end

  class FailingErrorSubscriber
    Error = Class.new(StandardError)

    def initialize(error)
      @error = error
    end

    def report(_error, handled:, severity:, context:, source:)
      raise @error
    end
  end

  test "subscriber errors are re-raised if no logger is set" do
    subscriber_error = FailingErrorSubscriber::Error.new("Big Oopsie")
    @reporter.subscribe(FailingErrorSubscriber.new(subscriber_error))
    assert_raises FailingErrorSubscriber::Error do
      @reporter.report(@error, handled: true)
    end
  end

  test "subscriber errors are logged if a logger is set" do
    subscriber_error = FailingErrorSubscriber::Error.new("Big Oopsie")
    @reporter.subscribe(FailingErrorSubscriber.new(subscriber_error))
    log = StringIO.new
    @reporter.logger = ActiveSupport::Logger.new(log)
    @reporter.report(@error, handled: true)

    expected = "Error subscriber raised an error: Big Oopsie (ErrorReporterTest::FailingErrorSubscriber::Error)"
    assert_equal expected, log.string.lines.first.chomp
  end
end
