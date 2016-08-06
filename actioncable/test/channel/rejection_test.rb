require "test_helper"
require "stubs/test_connection"
require "stubs/room"

class ActionCable::Channel::RejectionTest < ActiveSupport::TestCase
  class SecretChannel < ActionCable::Channel::Base
    def subscribed
      reject if params[:id] > 0
    end
  end

  setup do
    @user = User.new "lifo"
    @connection = TestConnection.new(@user)
  end

  test "subscription rejection" do
    @connection.expects(:subscriptions).returns mock().tap { |m| m.expects(:remove_subscription).with instance_of(SecretChannel) }
    @channel = SecretChannel.new @connection, "{id: 1}", id: 1

    expected = { "identifier" => "{id: 1}", "type" => "reject_subscription" }
    assert_equal expected, @connection.last_transmission
  end

end
