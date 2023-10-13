# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/execution_context/test_helper"
require "active_support/error_reporter/test_helper"

class ErrorReporterTest < ActiveSupport::TestCase
  # ExecutionContext is automatically reset in Rails app via executor hooks set in railtie
  # But not in Active Support's own test suite.
  include ActiveSupport::ExecutionContext::TestHelper
  include ActiveSupport::ErrorReporter::TestHelper

  setup do
    @reporter = ActiveSupport::ErrorReporter.new
    @subscriber = ActiveSupport::ErrorReporter::TestHelper::ErrorSubscriber.new
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

  test "#handle can be scoped to several exception classes" do
    assert_raises ArgumentError do
      @reporter.handle(NameError, NoMethodError) do
        raise ArgumentError
      end
    end
    assert_equal [], @subscriber.events
  end

  test "#handle swallows and reports matching errors" do
    error = ArgumentError.new("Oops")
    @reporter.handle(NameError, ArgumentError) do
      raise error
    end
    assert_equal [[error, true, :warning, "application", {}]], @subscriber.events
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

  test "#handle swallows and reports error when if condition is true" do
    error = ArgumentError.new("Oops")
    @reporter.handle(StandardError, if: true) do
      raise error
    end
    assert_equal [[error, true, :warning, "application", {}]], @subscriber.events
  end

  test "#handle raises the error and doesn't report when if condition is false" do
    error = ArgumentError.new("Oops")
    assert_raises ArgumentError do
      @reporter.handle(ArgumentError, if: false) do
        raise error
      end
    end
    assert_equal [], @subscriber.events
  end

  test "#handle executes the block once when condition isn't met and no error raised" do
    calls = 0
    @reporter.handle(if: false) do
      calls += 1
    end

    assert_equal 1, calls
  end

  test "#handle raises the error and doesn't report when unless condition is true" do
    error = ArgumentError.new("Oops")
    assert_raises ArgumentError do
      @reporter.handle(ArgumentError, unless: true) do
        raise error
      end
    end
    assert_equal [], @subscriber.events
  end

  test "#handle swallows and reports error when unless condition is false" do
    error = ArgumentError.new("Oops")
    @reporter.handle(StandardError, unless: false) do
      raise error
    end
    assert_equal [[error, true, :warning, "application", {}]], @subscriber.events
  end

  test "#handle can't use both if and unless conditions" do
    assert_raises ArgumentError do
      @reporter.handle(ArgumentError, if: true, unless: true) do
        "hello"
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

  test "#record can be scoped to several exception classes" do
    assert_raises ArgumentError do
      @reporter.record(NameError, NoMethodError) do
        raise ArgumentError
      end
    end
    assert_equal [], @subscriber.events
  end

  test "#record report any matching, unhandled error and re-raise them" do
    error = ArgumentError.new("Oops")
    assert_raises ArgumentError do
      @reporter.record(NameError, ArgumentError) do
        raise error
      end
    end
    assert_equal [[error, false, :error, "application", {}]], @subscriber.events
  end

  test "#record passes through the return value" do
    result = @reporter.record do
      2 + 2
    end
    assert_equal 4, result
  end

  test "#record reports error when if condition is true" do
    error = ArgumentError.new("Oops")
    assert_raises ArgumentError do
      @reporter.record(StandardError, if: true) do
        raise error
      end
    end
    assert_equal [[error, false, :error, "application", {}]], @subscriber.events
  end

  test "#record doesn't report when if condition is false" do
    error = ArgumentError.new("Oops")
    assert_raises ArgumentError do
      @reporter.record(ArgumentError, if: false) do
        raise error
      end
    end
    assert_equal [], @subscriber.events
  end

  test "#record doesn't report when unless condition is true" do
    error = ArgumentError.new("Oops")
    assert_raises ArgumentError do
      @reporter.record(ArgumentError, unless: true) do
        raise error
      end
    end
    assert_equal [], @subscriber.events
  end

  test "#record reports error when unless condition is false" do
    error = ArgumentError.new("Oops")
    assert_raises ArgumentError do
      @reporter.record(StandardError, unless: false) do
        raise error
      end
    end
    assert_equal [[error, false, :error, "application", {}]], @subscriber.events
  end

  test "#record executes the block once when condition isn't met and no error raised" do
    calls = 0
    @reporter.record(if: false) do
      calls += 1
    end

    assert_equal 1, calls
  end

  test "#record can't use both if and unless conditions" do
    assert_raises ArgumentError do
      @reporter.record(ArgumentError, if: true, unless: true) do
        "hello"
      end
    end
  end

  test "can have multiple subscribers" do
    second_subscriber = ErrorSubscriber.new
    @reporter.subscribe(second_subscriber)

    error = ArgumentError.new("Oops")
    @reporter.report(error, handled: true)

    assert_equal 1, @subscriber.events.size
    assert_equal 1, second_subscriber.events.size
  end

  test "can unsubscribe" do
    second_subscriber = ErrorSubscriber.new
    @reporter.subscribe(second_subscriber)

    error = ArgumentError.new("Oops")
    @reporter.report(error, handled: true)

    @reporter.unsubscribe(second_subscriber)

    error = ArgumentError.new("Oops 2")
    @reporter.report(error, handled: true)

    assert_equal 2, @subscriber.events.size
    assert_equal 1, second_subscriber.events.size

    @reporter.subscribe(second_subscriber)
    @reporter.unsubscribe(ErrorSubscriber)

    error = ArgumentError.new("Oops 3")
    @reporter.report(error, handled: true)

    assert_equal 2, @subscriber.events.size
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

  test "report errors only once" do
    assert_difference -> { @subscriber.events.size }, +1 do
      @reporter.report(@error, handled: false)
    end

    assert_no_difference -> { @subscriber.events.size } do
      3.times do
        @reporter.report(@error, handled: false)
      end
    end
  end

  test "can report frozen exceptions" do
    assert_difference -> { @subscriber.events.size }, +1 do
      @reporter.report(@error.freeze, handled: false)
    end
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
