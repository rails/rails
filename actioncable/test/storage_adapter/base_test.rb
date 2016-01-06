require 'test_helper'
require 'stubs/test_server'

class ActionCable::StorageAdapter::BaseTest < ActionCable::TestCase
  ## TEST THAT ERRORS ARE RETURNED FOR INHERITORS THAT DON'T OVERRIDE METHODS

  class BrokenAdapter < ActionCable::StorageAdapter::Base
  end

  setup do
    @server = TestServer.new
    @server.config.allowed_request_origins = %w( http://rubyonrails.com )
  end

  test "#broadcast returns NotImplementedError by default" do
    assert_raises NotImplementedError do
      BrokenAdapter.new(@server).broadcast
    end
  end

  test "#pubsub returns NotImplementedError by default" do
    assert_raises NotImplementedError do
      BrokenAdapter.new(@server).pubsub
    end
  end

  # TEST METHODS THAT ARE REQUIRED OF THE ADAPTER'S BACKEND STORAGE OBJECT

  class SuccessAdapterBackend
    def publish(channel, message)
    end

    def subscribe(*channels, &block)
    end

    def unsubscribe(*channels, &block)
    end
  end

  class SuccessAdapter < ActionCable::StorageAdapter::Base
    def broadcast
      SuccessAdapterBackend.new
    end

    def pubsub
      SuccessAdapterBackend.new
    end
  end

  test "#broadcast responds to #publish" do
    broadcast = SuccessAdapter.new(@server).broadcast
    assert_respond_to(broadcast, :publish)
  end

  test "#pubsub responds to #subscribe" do
    pubsub = SuccessAdapter.new(@server).pubsub
    assert_respond_to(pubsub, :subscribe)
  end

  test "#pubsub responds to #unsubscribe" do
    pubsub = SuccessAdapter.new(@server).pubsub
    assert_respond_to(pubsub, :unsubscribe)
  end
end
