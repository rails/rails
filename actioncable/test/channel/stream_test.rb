require 'test_helper'
require 'stubs/test_connection'
require 'stubs/room'

class ActionCable::Channel::StreamTest < ActionCable::TestCase
  class ChatChannel < ActionCable::Channel::Base
    def subscribed
      if params[:id]
        @room = Room.new params[:id]
        stream_from "test_room_#{@room.id}"
      end
    end

    def send_confirmation
      transmit_subscription_confirmation
    end

  end

  test "streaming start and stop" do
    run_in_eventmachine do
      connection = TestConnection.new
      connection.expects(:adapter).returns mock().tap { |m| m.expects(:subscribe).with("test_room_1", kind_of(Proc), kind_of(Proc)).returns stub_everything(:adapter) }
      channel = ChatChannel.new connection, "{id: 1}", { id: 1 }

      connection.expects(:adapter).returns mock().tap { |m| m.expects(:unsubscribe) }
      channel.unsubscribe_from_channel
    end
  end

  test "stream_for" do
    run_in_eventmachine do
      connection = TestConnection.new
      EM.next_tick do
        connection.expects(:adapter).returns mock().tap { |m| m.expects(:subscribe).with("action_cable:channel:stream_test:chat:Room#1-Campfire", kind_of(Proc), kind_of(Proc)).returns stub_everything(:adapter) }
      end

      channel = ChatChannel.new connection, ""
      channel.stream_for Room.new(1)
    end
  end

  test "stream_from subscription confirmation" do
    EM.run do
      connection = TestConnection.new

      ChatChannel.new connection, "{id: 1}", { id: 1 }
      assert_nil connection.last_transmission

      EM::Timer.new(0.1) do
        expected = ActiveSupport::JSON.encode "identifier" => "{id: 1}", "type" => "confirm_subscription"
        connection.transmit(expected)

        assert_equal expected, connection.last_transmission, "Did not receive subscription confirmation within 0.1s"

        EM.run_deferred_callbacks
        EM.stop
      end
    end
  end

  test "subscription confirmation should only be sent out once" do
    EM.run do
      connection = TestConnection.new
      connection.stubs(:pubsub).returns EM::Hiredis.connect.pubsub

      channel = ChatChannel.new connection, "test_channel"
      channel.send_confirmation
      channel.send_confirmation

      EM.run_deferred_callbacks

      expected = ActiveSupport::JSON.encode "identifier" => "test_channel", "type" => "confirm_subscription"
      assert_equal expected, connection.last_transmission, "Did not receive subscription confirmation"

      assert_equal 1, connection.transmissions.size
      EM.stop
    end
  end

end
