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
  end

  setup do
    @connection = TestConnection.new
  end

  test "streaming start and stop" do
    run_in_eventmachine do
      @connection.expects(:pubsub).returns mock().tap { |m| m.expects(:subscribe).with("test_room_1") }
      channel = ChatChannel.new @connection, "{id: 1}", { id: 1 }

      @connection.expects(:pubsub).returns mock().tap { |m| m.expects(:unsubscribe_proc) }
      channel.unsubscribe_from_channel
    end
  end

  test "stream_for" do
    run_in_eventmachine do
      EM.next_tick do
        @connection.expects(:pubsub).returns mock().tap { |m| m.expects(:subscribe).with("action_cable:channel:stream_test:chat:Room#1-Campfire") }
      end

      channel = ChatChannel.new @connection, ""
      channel.stream_for Room.new(1)
    end
  end
end
