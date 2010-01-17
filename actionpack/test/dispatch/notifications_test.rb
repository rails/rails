require 'abstract_unit'

class NotificationsMiddlewareTest < ActionController::IntegrationTest
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
    @queue    = ActiveSupport::Notifications::Fanout.new
    @notifier = ActiveSupport::Notifications::Notifier.new(@queue)
    ActiveSupport::Notifications.notifier = @notifier

    @events = []
    ActiveSupport::Notifications.subscribe do |*args|
      @events << args
    end

    @app = App
  end

  test "publishes notifications" do
    get "/"
    ActiveSupport::Notifications.notifier.wait

    assert_equal 2, @events.size
    before, after = @events

    assert_equal 'action_dispatch.before_dispatch', before[0]
    assert_kind_of Hash, before[4][:env]
    assert_equal 'GET',  before[4][:env]["REQUEST_METHOD"]

    assert_equal 'action_dispatch.after_dispatch', after[0]
    assert_kind_of Hash, after[4][:env]
    assert_equal 'GET',  after[4][:env]["REQUEST_METHOD"]
  end

  test "publishes notifications on failure" do
    begin
      get "/puke"
    rescue
    end

    ActiveSupport::Notifications.notifier.wait

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
end