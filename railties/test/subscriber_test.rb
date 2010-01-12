require 'abstract_unit'
require 'rails/subscriber'

Thread.abort_on_exception = true

class MockLogger
  def initialize
    @logged = Hash.new { |h,k| h[k] = [] }
  end

  def method_missing(level, message)
    @logged[level] << message
  end

  def logged(level)
    @logged[level].compact.map { |l| l.to_s.strip }
  end
end

ActiveSupport::Notifications.subscribe do |*args|
  Rails::Subscriber.dispatch(args)
end

class MySubscriber < Rails::Subscriber
  def some_event(event)
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
end

class SubscriberTest < ActiveSupport::TestCase
  def setup
    @logger = MockLogger.new
    @previous_logger, Rails.logger = Rails.logger, @logger
    @subscriber = MySubscriber.new
    wait
  end

  def teardown
    Rails.logger = @previous_logger
    Rails::Subscriber.subscribers.clear
  end

  def instrument(*args, &block)
    ActiveSupport::Notifications.instrument(*args, &block)
  end

  def wait
    ActiveSupport::Notifications.notifier.wait
  end

  def test_proxies_method_to_rails_logger
    @subscriber.foo(nil)
    assert_equal %w(debug), @logger.logged(:debug)
    assert_equal %w(info), @logger.logged(:info)
    assert_equal %w(warn), @logger.logged(:warn)
  end

  def test_set_color_for_messages
    @subscriber.bar(nil)
    assert_equal "\e[31mcool\e[0m, \e[1m\e[34misn't it?\e[0m", @logger.logged(:info).last
  end

  def test_does_not_set_color_if_colorize_logging_is_set_to_false
    Rails::Subscriber.colorize_logging = false
    @subscriber.bar(nil)
    assert_equal "cool, isn't it?", @logger.logged(:info).last
  ensure
    Rails::Subscriber.colorize_logging = true
  end

  def test_event_is_sent_to_the_registered_class
    Rails::Subscriber.add :my_subscriber, @subscriber
    instrument "my_subscriber.some_event"
    wait
    assert_equal %w(my_subscriber.some_event), @logger.logged(:info)
  end

  def test_does_not_send_the_event_if_it_doesnt_match_the_class
    Rails::Subscriber.add :my_subscriber, @subscriber
    instrument "my_subscriber.unknown_event"
    wait
    # If we get here, it means that NoMethodError was raised.
  end

  def test_does_not_send_the_event_if_logger_is_nil
    Rails.logger = nil
    Rails::Subscriber.add :my_subscriber, @subscriber
    instrument "my_subscriber.some_event"
    wait
    assert_equal [], @logger.logged(:info)
  end
end