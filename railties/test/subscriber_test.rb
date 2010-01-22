require 'abstract_unit'
require 'rails/subscriber/test_helper'

class MySubscriber < Rails::Subscriber
  attr_reader :event

  def some_event(event)
    @event = event
    info event.name
  end

  def foo(event)
    debug "debug"
    info "info"
    warn "warn"
  end

  def bar(event)
    info "#{color("cool", :red)}, #{color("isn't it?", :blue, true)}"
  end

  def puke(event)
    raise "puke"
  end
end

class SyncSubscriberTest < ActiveSupport::TestCase
  include Rails::Subscriber::TestHelper

  def setup
    super
    @subscriber = MySubscriber.new
    Rails::Subscriber.instance_variable_set(:@log_tailer, nil)
  end

  def teardown
    super
    Rails::Subscriber.subscribers.clear
    Rails::Subscriber.instance_variable_set(:@log_tailer, nil)
  end

  def instrument(*args, &block)
    ActiveSupport::Notifications.instrument(*args, &block)
  end

  def test_proxies_method_to_rails_logger
    @subscriber.foo(nil)
    assert_equal %w(debug), @logger.logged(:debug)
    assert_equal %w(info), @logger.logged(:info)
    assert_equal %w(warn), @logger.logged(:warn)
  end

  def test_set_color_for_messages
    Rails::Subscriber.colorize_logging = true
    @subscriber.bar(nil)
    assert_equal "\e[31mcool\e[0m, \e[1m\e[34misn't it?\e[0m", @logger.logged(:info).last
  end

  def test_does_not_set_color_if_colorize_logging_is_set_to_false
    @subscriber.bar(nil)
    assert_equal "cool, isn't it?", @logger.logged(:info).last
  end

  def test_event_is_sent_to_the_registered_class
    Rails::Subscriber.add :my_subscriber, @subscriber
    instrument "my_subscriber.some_event"
    wait
    assert_equal %w(my_subscriber.some_event), @logger.logged(:info)
  end

  def test_event_is_an_active_support_notifications_event
    Rails::Subscriber.add :my_subscriber, @subscriber
    instrument "my_subscriber.some_event"
    wait
    assert_kind_of ActiveSupport::Notifications::Event, @subscriber.event
  end

  def test_does_not_send_the_event_if_it_doesnt_match_the_class
    Rails::Subscriber.add :my_subscriber, @subscriber
    instrument "my_subscriber.unknown_event"
    wait
    # If we get here, it means that NoMethodError was raised.
  end

  def test_does_not_send_the_event_if_logger_is_nil
    Rails.logger = nil
    @subscriber.expects(:some_event).never
    Rails::Subscriber.add :my_subscriber, @subscriber
    instrument "my_subscriber.some_event"
    wait
  end

  def test_flushes_loggers
    Rails::Subscriber.add :my_subscriber, @subscriber
    Rails::Subscriber.flush_all!
    assert_equal 1, @logger.flush_count
  end

  def test_flushes_the_same_logger_just_once
    Rails::Subscriber.add :my_subscriber, @subscriber
    Rails::Subscriber.add :another, @subscriber
    Rails::Subscriber.flush_all!
    wait
    assert_equal 1, @logger.flush_count
  end

  def test_logging_does_not_die_on_failures
    Rails::Subscriber.add :my_subscriber, @subscriber
    instrument "my_subscriber.puke"
    instrument "my_subscriber.some_event"
    wait

    assert_equal 1, @logger.logged(:info).size
    assert_equal 'my_subscriber.some_event', @logger.logged(:info).last

    assert_equal 1, @logger.logged(:error).size
    assert_equal 'Could not log "my_subscriber.puke" event. RuntimeError: puke', @logger.logged(:error).last
  end
end