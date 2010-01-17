require "abstract_unit"
require "rails/subscriber/test_helper"
require "action_dispatch/railties/subscriber"

module DispatcherSubscriberTest
  Boomer = lambda do |env|
    req = ActionDispatch::Request.new(env)
    case req.path
    when "/"
      [200, {}, []]
    else
      raise "puke!"
    end
  end

  App = ActionDispatch::Notifications.new(Boomer)

  def setup
    Rails::Subscriber.add(:action_dispatch, ActionDispatch::Railties::Subscriber.new)
    @app = App
    super

    @events = []
    ActiveSupport::Notifications.subscribe do |*args|
      @events << args
    end
  end

  def set_logger(logger)
    ActionController::Base.logger = logger
  end

  def test_publishes_notifications
    get "/"
    wait

    assert_equal 2, @events.size
    before, after = @events

    assert_equal 'action_dispatch.before_dispatch', before[0]
    assert_kind_of Hash, before[4][:env]
    assert_equal 'GET',  before[4][:env]["REQUEST_METHOD"]

    assert_equal 'action_dispatch.after_dispatch', after[0]
    assert_kind_of Hash, after[4][:env]
    assert_equal 'GET',  after[4][:env]["REQUEST_METHOD"]
  end

  def test_publishes_notifications_even_on_failures
    begin
      get "/puke"
    rescue
    end

    wait

    assert_equal 3, @events.size
    before, after, exception = @events

    assert_equal 'action_dispatch.before_dispatch', before[0]
    assert_kind_of Hash, before[4][:env]
    assert_equal 'GET',  before[4][:env]["REQUEST_METHOD"]

    assert_equal 'action_dispatch.after_dispatch', after[0]
    assert_kind_of Hash, after[4][:env]
    assert_equal 'GET',  after[4][:env]["REQUEST_METHOD"]

    assert_equal 'action_dispatch.exception', exception[0]
    assert_kind_of Hash, exception[4][:env]
    assert_equal 'GET',  exception[4][:env]["REQUEST_METHOD"]
    assert_kind_of RuntimeError, exception[4][:exception]
  end

  def test_subscriber_logs_notifications
    get "/"
    wait

    log = @logger.logged(:info).first
    assert_equal 1, @logger.logged(:info).size

    assert_match %r{^Processing "/" to text/html}, log
    assert_match %r{\(for 127\.0\.0\.1}, log
    assert_match %r{\[GET\]}, log
  end

  def test_subscriber_has_its_logged_flushed_after_request
    assert_equal 0, @logger.flush_count
    get "/"
    wait
    assert_equal 1, @logger.flush_count
  end

  def test_subscriber_has_its_logged_flushed_even_after_busted_requests
    assert_equal 0, @logger.flush_count
    begin
      get "/puke"
    rescue
    end
    wait
    assert_equal 1, @logger.flush_count
  end

  class SyncSubscriberTest < ActionController::IntegrationTest
    include Rails::Subscriber::SyncTestHelper
    include DispatcherSubscriberTest
  end

  class AsyncSubscriberTest < ActionController::IntegrationTest
    include Rails::Subscriber::AsyncTestHelper
    include DispatcherSubscriberTest
  end
end