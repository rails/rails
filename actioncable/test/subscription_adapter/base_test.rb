require "test_helper"
require "stubs/test_server"

class ActionCable::SubscriptionAdapter::BaseTest < ActionCable::TestCase
  ## TEST THAT ERRORS ARE RETURNED FOR INHERITORS THAT DON'T OVERRIDE METHODS

  class BrokenAdapter < ActionCable::SubscriptionAdapter::Base
  end

  setup do
    @server = TestServer.new
    @server.config.subscription_adapter = BrokenAdapter
    @server.config.allowed_request_origins = %w( http://rubyonrails.com )
  end

  test "#broadcast returns NotImplementedError by default" do
    assert_raises NotImplementedError do
      BrokenAdapter.new(@server).broadcast("channel", "payload")
    end
  end

  test "#subscribe returns NotImplementedError by default" do
    callback = lambda { puts "callback" }
    success_callback = lambda { puts "success" }

    assert_raises NotImplementedError do
      BrokenAdapter.new(@server).subscribe("channel", callback, success_callback)
    end
  end

  test "#unsubscribe returns NotImplementedError by default" do
    callback = lambda { puts "callback" }

    assert_raises NotImplementedError do
      BrokenAdapter.new(@server).unsubscribe("channel", callback)
    end
  end

  # TEST METHODS THAT ARE REQUIRED OF THE ADAPTER'S BACKEND STORAGE OBJECT

  test "#broadcast is implemented" do
    broadcast = SuccessAdapter.new(@server).broadcast("channel", "payload")

    assert_respond_to(SuccessAdapter.new(@server), :broadcast)

    assert_nothing_raised do
      broadcast
    end
  end

  test "#subscribe is implemented" do
    callback = lambda { puts "callback" }
    success_callback = lambda { puts "success" }
    subscribe = SuccessAdapter.new(@server).subscribe("channel", callback, success_callback)

    assert_respond_to(SuccessAdapter.new(@server), :subscribe)

    assert_nothing_raised do
      subscribe
    end
  end

  test "#unsubscribe is implemented" do
    callback = lambda { puts "callback" }
    unsubscribe = SuccessAdapter.new(@server).unsubscribe("channel", callback)

    assert_respond_to(SuccessAdapter.new(@server), :unsubscribe)

    assert_nothing_raised do
      unsubscribe
    end
  end
end
