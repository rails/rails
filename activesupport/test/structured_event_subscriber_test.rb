# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/testing/event_reporter_assertions"
require "active_support/log_subscriber/test_helper"

class StructuredEventSubscriberTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::EventReporterAssertions

  class TestEventReporterSubscriber
    def emit(payload)
    end
  end

  class TestSubscriber < ActiveSupport::StructuredEventSubscriber
    class DebugOnlyError < StandardError
    end

    def event(event)
      emit_event("test.event", **event.payload)
    end

    def debug_only_event(event)
      raise DebugOnlyError
    end
    debug_only :debug_only_event
  end

  class NamespacedSubscriber < ActiveSupport::StructuredEventSubscriber
    self.event_namespace = "test"

    def debug_event(event)
      emit_event("test.debug_event")
    end

    def info_event(event)
      emit_event("test.info_event")
    end
  end

  class TestLogSubscriber < ActiveSupport::EventReporter::LogSubscriber
    self.namespace = "test"

    def debug_event(event)
      debug "debug event"
    end
    event_log_level :debug_event, :debug

    def info_event(event)
      info "info event"
    end
    event_log_level :info_event, :info
  end

  class OtherLogSubscriber < ActiveSupport::EventReporter::LogSubscriber
    self.namespace = "other"

    def error_event(event)
      error "error event"
    end
    event_log_level :error_event, :error
  end

  setup do
    @subscriber = TestSubscriber.new
    @old_debug_mode = ActiveSupport.event_reporter.debug_mode?
    ActiveSupport.event_reporter.debug_mode = false
  end

  teardown do
    ActiveSupport.event_reporter.debug_mode = @old_debug_mode
    TestSubscriber.detach_from :test
    ActiveSupport::StructuredEventSubscriber.detach_from :test
  end

  def test_emit_event_calls_event_reporter_notify
    event = assert_event_reported("test.event", payload: { key: "value" }) do
      @subscriber.emit_event("test.event", { key: "value" })
    end

    assert_equal "test.event", event[:name]
    assert_equal({ key: "value" }, event[:payload])
  end

  def test_emit_debug_event_calls_event_reporter_debug
    with_debug_event_reporting do
      assert_event_reported("test.debug", payload: { debug: "info" }) do
        @subscriber.emit_debug_event("test.debug", { debug: "info" })
      end
    end
  end

  def test_emit_event_handles_errors
    ActiveSupport.event_reporter.stub(:notify, proc { raise StandardError, "event error" }) do
      error_report = assert_error_reported(StandardError) do
        @subscriber.emit_event("test.error")
      end
      assert_equal "test.error", error_report.source
      assert_equal "event error", error_report.error.message
    end
  end

  def test_emit_debug_event_handles_errors
    ActiveSupport.event_reporter.stub(:debug, proc { raise StandardError, "debug error" }) do
      error_report = assert_error_reported(StandardError) do
        @subscriber.emit_debug_event("test.debug_error")
      end
      assert_equal "test.debug_error", error_report.source
      assert_equal "debug error", error_report.error.message
    end
  end

  def test_call_handles_errors
    ActiveSupport::StructuredEventSubscriber.attach_to :test, @subscriber

    event = ActiveSupport::Notifications::Event.new("error_event.test", Time.current, Time.current, "123", {})

    error_report = assert_error_reported(NoMethodError) do
      @subscriber.call(event)
    end
    assert_match(/undefined method (`|')error_event'/, error_report.error.message)
    assert_equal "error_event.test", error_report.source
  end

  def test_debug_only_methods
    TestSubscriber.attach_to :test, @subscriber

    event_reporter_subscriber = TestEventReporterSubscriber.new
    ActiveSupport.event_reporter.subscribe(event_reporter_subscriber)

    assert_no_error_reported do
      ActiveSupport::Notifications.instrument("debug_only_event.test")
    end

    assert_error_reported(TestSubscriber::DebugOnlyError) do
      with_debug_event_reporting do
        ActiveSupport::Notifications.instrument("debug_only_event.test")
      end
    end
  ensure
    ActiveSupport.event_reporter.unsubscribe(event_reporter_subscriber)
  end

  def test_debug_only_does_not_leak_across_subclasses
    base_methods = ActiveSupport::StructuredEventSubscriber.debug_methods.dup

    subscriber_a = Class.new(ActiveSupport::StructuredEventSubscriber) do
      def foo(event); end
      debug_only :foo
    end

    subscriber_b = Class.new(ActiveSupport::StructuredEventSubscriber) do
      def bar(event); end
      debug_only :bar
    end

    assert_equal [:foo], subscriber_a.debug_methods
    assert_equal [:bar], subscriber_b.debug_methods
    assert_equal base_methods, ActiveSupport::StructuredEventSubscriber.debug_methods
  end

  def test_no_event_reporter_subscribers
    ActiveSupport::StructuredEventSubscriber.attach_to :test, @subscriber

    old_subscribers = ActiveSupport.event_reporter.subscribers.dup
    ActiveSupport.event_reporter.subscribers.clear

    assert_not_called @subscriber, :emit_event do
      ActiveSupport::Notifications.instrument("event.test")
    end
  ensure
    ActiveSupport.event_reporter.subscribers.push(*old_subscribers)
  end

  def test_emit_event_does_not_filter_payload
    old_filter_parameters = ActiveSupport.filter_parameters
    ActiveSupport.filter_parameters = [:name, :url, :message, :description]
    ActiveSupport.event_reporter.reload_payload_filter

    event = assert_event_reported("test.event", payload: { name: "Person Load", url: "/test", message: "hello", description: "a thing" }) do
      @subscriber.emit_event("test.event", name: "Person Load", url: "/test", message: "hello", description: "a thing")
    end

    assert_equal "Person Load", event[:payload][:name]
    assert_equal "/test", event[:payload][:url]
    assert_equal "hello", event[:payload][:message]
    assert_equal "a thing", event[:payload][:description]
  ensure
    ActiveSupport.filter_parameters = old_filter_parameters
    ActiveSupport.event_reporter.reload_payload_filter
  end

  def test_emit_debug_event_does_not_filter_payload
    old_filter_parameters = ActiveSupport.filter_parameters
    ActiveSupport.filter_parameters = [:name]
    ActiveSupport.event_reporter.reload_payload_filter

    with_debug_event_reporting do
      event = assert_event_reported("test.debug", payload: { name: "Person Load" }) do
        @subscriber.emit_debug_event("test.debug", name: "Person Load")
      end

      assert_equal "Person Load", event[:payload][:name]
    end
  ensure
    ActiveSupport.filter_parameters = old_filter_parameters
    ActiveSupport.event_reporter.reload_payload_filter
  end

  def test_silenced_when_logger_level_is_above_all_events_in_namespace
    logger = log_subscriber_logger(:warn)

    with_event_reporter_subscribers(test_log_subscriber_entry) do
      subscriber = NamespacedSubscriber.new
      assert subscriber.silenced?("info_event.test")
      assert subscriber.silenced?("debug_event.test")

      NamespacedSubscriber.attach_to :test, subscriber
      assert_not_called subscriber, :info_event do
        ActiveSupport::Notifications.instrument("info_event.test")
      end
      assert_empty logger.logged(:info)
    end
  ensure
    NamespacedSubscriber.detach_from :test
  end

  def test_not_silenced_when_logger_level_allows_any_event_in_namespace
    logger = log_subscriber_logger(:info)

    with_event_reporter_subscribers(test_log_subscriber_entry) do
      subscriber = NamespacedSubscriber.new
      assert_not subscriber.silenced?("info_event.test")
      assert_not subscriber.silenced?("debug_event.test")

      NamespacedSubscriber.attach_to :test, subscriber
      ActiveSupport::Notifications.instrument("info_event.test")
      ActiveSupport::Notifications.instrument("debug_event.test")
      assert_equal ["info event"], logger.logged(:info)
      assert_empty logger.logged(:debug)
    end
  ensure
    NamespacedSubscriber.detach_from :test
  end

  def test_silencing_follows_logger_level_changes
    logger = log_subscriber_logger(:warn)

    with_event_reporter_subscribers(test_log_subscriber_entry) do
      subscriber = NamespacedSubscriber.new
      assert subscriber.silenced?("info_event.test")

      logger.level = Logger::DEBUG
      assert_not subscriber.silenced?("info_event.test")

      logger.level = Logger::ERROR
      ActiveSupport::StructuredEventSubscriber::CHECKS_SKIPPED_WHILE_NOT_IGNORED.times do
        assert_not subscriber.silenced?("info_event.test")
      end
      assert subscriber.silenced?("info_event.test")
      assert subscriber.silenced?("info_event.test")
    end
  end

  def test_checks_are_skipped_for_a_while_once_events_are_not_ignored
    logger = log_subscriber_logger(:info)

    with_event_reporter_subscribers(test_log_subscriber_entry) do
      subscriber = NamespacedSubscriber.new
      assert_not subscriber.silenced?("info_event.test")

      assert_not_called(logger, :info?) do
        assert_not_called(logger, :debug?) do
          ActiveSupport::StructuredEventSubscriber::CHECKS_SKIPPED_WHILE_NOT_IGNORED.times do
            assert_not subscriber.silenced?("info_event.test")
          end
        end
      end

      assert_called(logger, :info?, returns: true) do
        assert_not subscriber.silenced?("info_event.test")
      end
    end
  end

  def test_silenced_when_log_subscribers_only_accept_other_namespaces
    OtherLogSubscriber.logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new(Logger::DEBUG)
    other = OtherLogSubscriber.new

    with_event_reporter_subscribers({ subscriber: other, filter: OtherLogSubscriber.subscription_filter }) do
      subscriber = NamespacedSubscriber.new
      assert_not_called OtherLogSubscriber.logger, :error? do
        assert subscriber.silenced?("info_event.test")
      end
    end
  ensure
    OtherLogSubscriber.logger = nil
  end

  def test_silenced_when_log_subscriber_logger_is_nil
    TestLogSubscriber.logger = nil
    log_subscriber = Class.new(TestLogSubscriber) { def self.default_logger = nil }.new

    with_event_reporter_subscribers({ subscriber: log_subscriber, filter: TestLogSubscriber.subscription_filter }) do
      assert NamespacedSubscriber.new.silenced?("info_event.test")
    end
  end

  def test_not_silenced_when_an_unfiltered_log_subscriber_may_log
    OtherLogSubscriber.logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new(Logger::ERROR)

    with_event_reporter_subscribers({ subscriber: OtherLogSubscriber.new, filter: nil }) do
      assert_not NamespacedSubscriber.new.silenced?("info_event.test")

      OtherLogSubscriber.logger.level = Logger::FATAL
      assert NamespacedSubscriber.new.silenced?("info_event.test")
    end
  ensure
    OtherLogSubscriber.logger = nil
  end

  def test_not_silenced_with_other_event_reporter_subscribers
    log_subscriber_logger(:warn)

    with_event_reporter_subscribers(test_log_subscriber_entry, { subscriber: TestEventReporterSubscriber.new, filter: nil }) do
      assert_not NamespacedSubscriber.new.silenced?("info_event.test")
    end
  end

  def test_not_silenced_without_event_namespace
    log_subscriber_logger(:warn)

    with_event_reporter_subscribers(test_log_subscriber_entry) do
      assert_not TestSubscriber.new.silenced?("event.test")
      assert_nil Class.new(NamespacedSubscriber).event_namespace
      assert_not Class.new(NamespacedSubscriber).new.silenced?("info_event.test")
    end
  end

  def test_not_silenced_by_subscribers_resembling_log_subscribers
    log_subscriber_logger(:warn)
    lookalike = Class.new(TestEventReporterSubscriber) do
      def log_levels = {}
      def log_level_predicates_for(*) = []
    end

    with_event_reporter_subscribers({ subscriber: lookalike.new, filter: nil }) do
      assert_not NamespacedSubscriber.new.silenced?("info_event.test")
    end
  end

  def test_not_silenced_when_log_subscriber_overrides_emit
    log_subscriber_class = Class.new(TestLogSubscriber) { def emit(event) = super }
    log_subscriber_class.logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new(Logger::WARN)

    with_event_reporter_subscribers({ subscriber: log_subscriber_class.new, filter: TestLogSubscriber.subscription_filter }) do
      assert_not NamespacedSubscriber.new.silenced?("info_event.test")
    end
  end

  def test_silenced_when_events_use_levels_never_logged
    log_subscriber_class = Class.new(ActiveSupport::EventReporter::LogSubscriber) do
      def info_event(event); end
      event_log_level :info_event, :warn
    end
    log_subscriber_class.logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new(Logger::WARN)

    with_event_reporter_subscribers({ subscriber: log_subscriber_class.new, filter: nil }) do
      assert NamespacedSubscriber.new.silenced?("info_event.test")
    end
  end

  def test_not_silenced_when_filter_raises
    log_subscriber_logger(:warn)
    filter = proc { raise "filter error" }

    with_event_reporter_subscribers({ subscriber: TestLogSubscriber.new, filter: filter }) do
      assert_not NamespacedSubscriber.new.silenced?("info_event.test")
    end
  end

  def test_not_silenced_when_log_subscriber_logger_raises
    TestLogSubscriber.logger = nil

    with_event_reporter_subscribers(test_log_subscriber_entry) do
      assert_raises(NotImplementedError) { TestLogSubscriber.logger }
      assert_not NamespacedSubscriber.new.silenced?("info_event.test")
    end
  end

  def test_silencing_follows_log_level_changes
    log_subscriber_class = Class.new(ActiveSupport::EventReporter::LogSubscriber) do
      def debug_event(event); end
      event_log_level :debug_event, :debug
    end
    log_subscriber_class.logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new(Logger::INFO)

    with_event_reporter_subscribers({ subscriber: log_subscriber_class.new, filter: nil }) do
      subscriber = NamespacedSubscriber.new
      assert subscriber.silenced?("info_event.test")
      assert subscriber.silenced?("info_event.test")

      log_subscriber_class.event_log_level :info_event, :info
      assert_not subscriber.silenced?("info_event.test")
    end
  end

  private
    def log_subscriber_logger(level)
      TestLogSubscriber.logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new(Logger.const_get(level.upcase))
    end

    def test_log_subscriber_entry
      { subscriber: TestLogSubscriber.new, filter: TestLogSubscriber.subscription_filter }
    end

    def with_event_reporter_subscribers(*entries)
      subscribers = ActiveSupport.event_reporter.subscribers
      old_subscribers = subscribers.dup
      subscribers.replace(entries)
      yield
    ensure
      subscribers.replace(old_subscribers)
      TestLogSubscriber.logger = nil
    end
end
