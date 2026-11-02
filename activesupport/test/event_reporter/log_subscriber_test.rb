# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/log_subscriber/test_helper"
require "active_support/testing/ractors_assertions"

class ActiveSupport::EventReporter::LogSubscriberTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::RactorsAssertions
  class MyLogSubscriber < ActiveSupport::EventReporter::LogSubscriber
    self.namespace = "test"

    def debug_only(event)
      debug "hello #{event[:name]}"
    end
    event_log_level :debug_only, :debug

    def info_only(event)
      info "hello #{event[:name]}"
    end
    event_log_level :info_only, :info

    def error_only(event)
      error "hello #{event[:name]}"
    end
    event_log_level :error_only, :error

    def warn_level(event)
      warn "hello #{event[:name]}"
    end
    event_log_level :warn_level, :warn

    def no_level(event)
      info "hello #{event[:name]}"
    end
  end

  setup do
    @old_logger = nil
    @logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new
    @log_subscriber = MyLogSubscriber.new
    MyLogSubscriber.logger = @logger
    ActiveSupport.event_reporter.subscribe(@log_subscriber, &MyLogSubscriber.subscription_filter)
  end

  teardown do
    MyLogSubscriber.logger = @old_logger
    ActiveSupport.event_reporter.unsubscribe(@log_subscriber)
  end

  test "consumes? follows the logger level" do
    @logger.level = Logger::INFO

    assert @log_subscriber.consumes?("test.info_only")
    assert @log_subscriber.consumes?("test.error_only")
    assert_not @log_subscriber.consumes?("test.debug_only")
    assert_not @log_subscriber.consumes?("test.no_level")

    @logger.level = Logger::DEBUG
    assert @log_subscriber.consumes?("test.debug_only")
  end

  test "events nobody would log are not built" do
    @logger.level = Logger::ERROR
    # A dedicated reporter: the shared one may carry subscribers from other
    # tests (such as the event reporter assertions' collector) that consume
    # every event.
    reporter = ActiveSupport::EventReporter.new(raise_on_error: true)
    reporter.subscribe(@log_subscriber, &MyLogSubscriber.subscription_filter)

    assert_not reporter.emitting?("test.info_only")
    reporter.notify("test.info_only")
    assert_empty @logger.logged(:info)

    @logger.level = Logger::INFO
    assert reporter.emitting?("test.info_only")
  end

  test "event_method_for maps an event name to its handler method" do
    assert_equal "info_only", ActiveSupport::EventReporter::LogSubscriber.event_method_for("test.info_only")
    assert_equal "info_only", ActiveSupport::EventReporter::LogSubscriber.event_method_for("other.info_only")
    assert_equal "no_namespace", ActiveSupport::EventReporter::LogSubscriber.event_method_for("no_namespace")
  end

  test "info logging" do
    ActiveSupport.event_reporter.notify("test.info_only")
    assert_equal ["hello test.info_only"], @logger.logged(:info)
  end

  test "error logging" do
    ActiveSupport.event_reporter.notify("test.error_only")
    assert_equal ["hello test.error_only"], @logger.logged(:error)
  end

  test "debug logging" do
    ActiveSupport.event_reporter.notify("test.debug_only")
    assert_equal ["hello test.debug_only"], @logger.logged(:debug)
  end

  test "filtered logging" do
    @logger.level = :info
    ActiveSupport.event_reporter.notify("test.debug_only")
    assert_empty @logger.logged(:debug)
  end

  test "events without a supported log level are not logged" do
    ActiveSupport.event_reporter.notify("test.warn_level")
    ActiveSupport.event_reporter.notify("test.no_level")

    assert_empty @logger.logged(:info)
  end

  test "default logger" do
    MyLogSubscriber.logger = nil

    assert_raises(NotImplementedError) do
      MyLogSubscriber.logger
    end

    subclass = Class.new(MyLogSubscriber) do
      def self.default_logger
        ActiveSupport::LogSubscriber::TestHelper::MockLogger.new
      end
    end

    assert_instance_of(ActiveSupport::LogSubscriber::TestHelper::MockLogger, subclass.logger)
  end

  test "nil logger" do
    MyLogSubscriber.logger = nil

    subclass = Class.new(MyLogSubscriber) do
      def self.default_logger
        nil
      end
    end

    assert_nothing_raised { subclass.new.emit(name: "test.debug_only") }
  end

  test ".subscription_filter" do
    event_reporter_raise_on_error do
      ActiveSupport.event_reporter.notify("other_namespace_that_shouldnt_work.info_only")
      assert_equal [], @logger.logged(:info)

      ActiveSupport.event_reporter.notify("no_namespace_info_only")
      assert_equal [], @logger.logged(:info)
    end
  end

  test "MyLogSubscriber.event_log_level is ractor safe" do
    assert_ractor_shareable MyLogSubscriber.log_levels
  end

  private
    def event_reporter_raise_on_error
      ActiveSupport.event_reporter.raise_on_error = true
      yield
    ensure
      ActiveSupport.event_reporter.raise_on_error = false
    end
end
