# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/log_subscriber/test_helper"

class ActiveSupport::EventReporter::LogSubscriberTest < ActiveSupport::TestCase
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

  test ".subscription_filter" do
    event_reporter_raise_on_error do
      ActiveSupport.event_reporter.notify("other_namespace_that_shouldnt_work.info_only")
      assert_equal [], @logger.logged(:info)

      ActiveSupport.event_reporter.notify("no_namespace_info_only")
      assert_equal [], @logger.logged(:info)
    end
  end

  private
    def event_reporter_raise_on_error
      ActiveSupport.event_reporter.raise_on_error = true
      yield
    ensure
      ActiveSupport.event_reporter.raise_on_error = false
    end
end
