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

  test "#report assigns a backtrace if it's missing" do
    error = RuntimeError.new("Oops")
    assert_nil error.backtrace
    assert_nil error.backtrace_locations

    assert_nil @reporter.report(error)
    assert_not_predicate error.backtrace, :empty?
    assert_not_predicate error.backtrace_locations, :empty?
  end

  test "#record passes through the return value" do
    result = @reporter.record do
      2 + 2
    end
    assert_equal 4, result
  end

  test "#unexpected swallows errors by default" do
    error = RuntimeError.new("Oops")
    assert_nil @reporter.unexpected(error)
    assert_equal [[error, true, :warning, "application", {}]], @subscriber.events
    assert_not_predicate error.backtrace, :empty?
    assert_not_predicate error.backtrace_locations, :empty?
  end

  test "#unexpected accepts an error message" do
    assert_nil @reporter.unexpected("Oops")
    assert_equal 1, @subscriber.events.size

    error, *event_details = @subscriber.events.first
    assert_equal [true, :warning, "application", {}], event_details

    assert_equal "Oops", error.message
    assert_equal RuntimeError, error.class
    assert_not_predicate error.backtrace, :empty?
  end

  test "#unexpected re-raise errors in development and test" do
    @reporter.debug_mode = true
    error = RuntimeError.new("Oops")
    raise_line = __LINE__ + 2
    raised_error = assert_raises ActiveSupport::ErrorReporter::UnexpectedError do
      @reporter.unexpected(error)
    end
    assert_includes raised_error.message, "RuntimeError: Oops"
    assert_not_nil raised_error.cause
    assert_same error, raised_error.cause
    assert_includes raised_error.backtrace.first, "#{__FILE__}:#{raise_line}"
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

  test "errors be reported with valid severity" do
    ActiveSupport::ErrorReporter::SEVERITIES.each do |severity|
      @reporter.report(StandardError.new, severity: severity)
      assert_equal severity, @subscriber.events.last[2]
    end
  end

  test "errors with invalid severity raise" do
    assert_raises ArgumentError do
      @reporter.report(@error, severity: :invalid)
    end
  end

  test "report raises if passed an argument that is not an Exception" do
    error = assert_raises ArgumentError do
      @reporter.report(Object.new)
    end
    assert_includes error.message, "Reported error must be an Exception"
  end

  test "report raises if passed a String" do
    error = assert_raises ArgumentError do
      @reporter.report("An error message")
    end
    assert_includes error.message, "Reported error must be an Exception"
  end

  test "report accepts context as nil" do
    @reporter.report(@error, context: nil)
    assert_equal({}, @subscriber.events.last[4])
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

  test "causes can't be reported again either" do
    begin
      begin
        begin
          raise "Original"
        rescue
          raise "Another"
        end
      rescue
        raise "Yet Another"
      end
    rescue => @error
    end

    assert_difference -> { @subscriber.events.size }, +1 do
      @reporter.report(@error, handled: false)
    end

    assert_no_difference -> { @subscriber.events.size } do
      3.times do
        @reporter.report(@error.cause.cause, handled: false)
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
