# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/log_subscriber/test_helper"

class SyncLogSubscriberTest < ActiveSupport::TestCase
  include ActiveSupport::LogSubscriber::TestHelper

  class MyLogSubscriber < ActiveSupport::LogSubscriber
    attr_reader :event

    def some_event(event)
      @event = event
      info event.name
    end

    def foo(event)
      debug "debug"
      info { "info" }
      warn "warn"
    end

    def bar(event)
      info "#{color("cool", :red)}, #{color("isn't it?", :blue, bold: true)}"
    end

    def baz(event)
      info "#{color("rad", :green, bold: true, underline: true)}, #{color("isn't it?", :yellow, italic: true)}"
    end

    def puke(event)
      raise "puke"
    end

    def debug_only(event)
      debug "debug logs are enabled"
    end
    subscribe_log_level :debug_only, :debug
  end

  def setup
    super
    @log_subscriber = MyLogSubscriber.new
  end

  def teardown
    super
    ActiveSupport::LogSubscriber.log_subscribers.clear
  end

  def test_proxies_method_to_rails_logger
    @log_subscriber.foo(nil)
    assert_equal %w(debug), @logger.logged(:debug)
    assert_equal %w(info), @logger.logged(:info)
    assert_equal %w(warn), @logger.logged(:warn)
  end

  def test_set_color_for_messages
    ActiveSupport::LogSubscriber.colorize_logging = true
    @log_subscriber.bar(nil)
    assert_equal "\e[31mcool\e[0m, \e[1m\e[34misn't it?\e[0m", @logger.logged(:info).last
  end

  def test_set_mode_for_messages
    ActiveSupport::LogSubscriber.colorize_logging = true
    @log_subscriber.baz(nil)
    assert_equal "\e[1;4m\e[32mrad\e[0m, \e[3m\e[33misn't it?\e[0m", @logger.logged(:info).last
  end

  def test_does_not_set_color_if_colorize_logging_is_set_to_false
    @log_subscriber.bar(nil)
    assert_equal "cool, isn't it?", @logger.logged(:info).last
  end

  def test_event_is_sent_to_the_registered_class
    ActiveSupport::LogSubscriber.attach_to :my_log_subscriber, @log_subscriber
    instrument "some_event.my_log_subscriber"
    wait
    assert_equal %w(some_event.my_log_subscriber), @logger.logged(:info)
  end

  def test_event_is_an_active_support_notifications_event
    ActiveSupport::LogSubscriber.attach_to :my_log_subscriber, @log_subscriber
    instrument "some_event.my_log_subscriber"
    wait
    assert_kind_of ActiveSupport::Notifications::Event, @log_subscriber.event
  end

  def test_event_attributes
    ActiveSupport::LogSubscriber.attach_to :my_log_subscriber, @log_subscriber
    instrument "some_event.my_log_subscriber" do
      [] # Make an allocation
    end
    wait
    event = @log_subscriber.event
    if defined?(JRUBY_VERSION)
      assert_equal 0, event.cpu_time
      assert_equal 0, event.allocations
    else
      assert_operator event.cpu_time, :>, 0
      assert_operator event.allocations, :>, 0
    end
    assert_operator event.duration, :>, 0
    assert_operator event.idle_time, :>=, 0
  end

  def test_does_not_send_the_event_if_it_doesnt_match_the_class
    assert_nothing_raised do
      ActiveSupport::LogSubscriber.attach_to :my_log_subscriber, @log_subscriber
      instrument "unknown_event.my_log_subscriber"
      wait
    end
  end

  def test_does_not_send_the_event_if_logger_is_nil
    ActiveSupport::LogSubscriber.logger = nil
    assert_not_called(@log_subscriber, :some_event) do
      ActiveSupport::LogSubscriber.attach_to :my_log_subscriber, @log_subscriber
      instrument "some_event.my_log_subscriber"
      wait
    end
  end

  def test_does_not_fail_with_non_namespaced_events
    assert_nothing_raised do
      ActiveSupport::LogSubscriber.attach_to :my_log_subscriber, @log_subscriber
      instrument "whatever"
      wait
    end
  end

  def test_flushes_loggers
    ActiveSupport::LogSubscriber.attach_to :my_log_subscriber, @log_subscriber
    ActiveSupport::LogSubscriber.flush_all!
    assert_equal 1, @logger.flush_count
  end

  def test_flushes_the_same_logger_just_once
    ActiveSupport::LogSubscriber.attach_to :my_log_subscriber, @log_subscriber
    ActiveSupport::LogSubscriber.attach_to :another, @log_subscriber
    ActiveSupport::LogSubscriber.flush_all!
    wait
    assert_equal 1, @logger.flush_count
  end

  def test_logging_does_not_die_on_failures
    assert_error_reported do
      ActiveSupport::LogSubscriber.attach_to :my_log_subscriber, @log_subscriber
      instrument "puke.my_log_subscriber"
      instrument "some_event.my_log_subscriber"
      wait
    end

    assert_equal 1, @logger.logged(:info).size
    assert_equal "some_event.my_log_subscriber", @logger.logged(:info).last

    assert_equal 1, @logger.logged(:error).size
    assert_match 'Could not log "puke.my_log_subscriber" event. RuntimeError: puke', @logger.logged(:error).last
  end

  def test_subscribe_log_level
    MyLogSubscriber.logger = @logger
    @logger.level = Logger::INFO
    MyLogSubscriber.attach_to :my_log_subscriber, @log_subscriber
    assert_empty @logger.logged(:debug)

    instrument "debug_only.my_log_subscriber"
    wait
    assert_empty @logger.logged(:debug)

    @logger.level = Logger::DEBUG
    instrument "debug_only.my_log_subscriber"
    wait
    assert_not_empty @logger.logged(:debug)
  end

  class MockSemanticLogger < MockLogger
    LEVELS = [:debug, :info]
    def level
      LEVELS[super]
    end
  end

  def test_subscribe_log_level_with_non_numeric_levels
    # The semantic_logger gem doesn't returns integers but symbols as levels
    @logger = MockSemanticLogger.new
    set_logger(@logger)
    MyLogSubscriber.logger = @logger
    @logger.level = Logger::INFO
    MyLogSubscriber.attach_to :my_log_subscriber, @log_subscriber
    assert_empty @logger.logged(:debug)

    instrument "debug_only.my_log_subscriber"
    wait
    assert_empty @logger.logged(:debug)

    @logger.level = Logger::DEBUG
    instrument "debug_only.my_log_subscriber"
    wait
    assert_not_empty @logger.logged(:debug)
  end

  private
    def instrument(*args, &block)
      ActiveSupport::Notifications.instrument(*args, &block)
    end
end
