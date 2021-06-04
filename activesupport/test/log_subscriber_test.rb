# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/log_subscriber/test_helper"

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
    info "#{color("cool", :red)}, #{color("isn't it?", :blue, true)}"
  end

  def puke(event)
    raise "puke"
  end
end

class SyncLogSubscriberTest < ActiveSupport::TestCase
  include ActiveSupport::LogSubscriber::TestHelper

  def setup
    super
    @log_subscriber = MyLogSubscriber.new
  end

  def teardown
    super
    ActiveSupport::LogSubscriber.log_subscribers.clear
  end

  def instrument(*args, &block)
    ActiveSupport::Notifications.instrument(*args, &block)
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
    instrument "some_event.my_log_subscriber"
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
    assert_operator event.idle_time, :>, 0
  end

  def test_does_not_send_the_event_if_it_doesnt_match_the_class
    ActiveSupport::LogSubscriber.attach_to :my_log_subscriber, @log_subscriber
    instrument "unknown_event.my_log_subscriber"
    wait
    # If we get here, it means that NoMethodError was not raised.
  end

  def test_does_not_send_the_event_if_logger_is_nil
    ActiveSupport::LogSubscriber.logger = nil
    assert_not_called(@log_subscriber, :some_event) do
      ActiveSupport::LogSubscriber.attach_to :my_log_subscriber, @log_subscriber
      instrument "some_event.my_log_subscriber"
      wait
    end
  end

  def test_does_not_send_buffered_events_if_logger_is_nil
    ActiveSupport::LogSubscriber.logger = nil
    assert_not_called(@log_subscriber, :some_event) do
      ActiveSupport::LogSubscriber.attach_to :my_log_subscriber, @log_subscriber
      buffer = ActiveSupport::Notifications.instrumenter.buffer
      buffer.instrument "some_event.my_log_subscriber"
      buffer.flush
      wait
    end
  end

  def test_does_not_fail_with_non_namespaced_events
    ActiveSupport::LogSubscriber.attach_to :my_log_subscriber, @log_subscriber
    instrument "whatever"
    wait
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
    ActiveSupport::LogSubscriber.attach_to :my_log_subscriber, @log_subscriber
    instrument "puke.my_log_subscriber"
    instrument "some_event.my_log_subscriber"
    wait

    assert_equal 1, @logger.logged(:info).size
    assert_equal "some_event.my_log_subscriber", @logger.logged(:info).last

    assert_equal 1, @logger.logged(:error).size
    assert_match 'Could not log "puke.my_log_subscriber" event. RuntimeError: puke', @logger.logged(:error).last
  end
end
