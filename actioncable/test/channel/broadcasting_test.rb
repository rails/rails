require 'test_helper'
require 'stubs/test_connection'
require 'stubs/room'

class ActionCable::Channel::BroadcastingTest < ActiveSupport::TestCase
  class ChatChannel < ActionCable::Channel::Base
  end

  setup do
    @connection = TestConnection.new
  end

  test "broadcasts_to" do
    ActionCable.stubs(:server).returns mock().tap { |m| m.expects(:broadcast).with('action_cable:channel:broadcasting_test:chat:Room#1-Campfire', "Hello World") }
    ChatChannel.broadcast_to(Room.new(1), "Hello World")
  end

  test "broadcast_to with single argument" do
    proxy = ChatChannel.broadcast_to(Room.new(1))
    assert_instance_of ActionCable::Channel::Broadcasting::EventProxy, proxy
  end

  test "proxied methods are converted in an event hash" do
    ActionCable.stubs(:server).returns (server = mock)
    arguments = {event_name: :some_event, args: [:foo, :bar]}
    server.expects(:broadcast).with('action_cable:channel:broadcasting_test:chat:Room#1-Campfire', arguments)
    # Proxied methods are converted into json messages and broadcasted
    ChatChannel.broadcast_to(Room.new(1)).some_event(:foo, :bar)
    # Without arguments it only broadcast event name
    server.expects(:broadcast).with('action_cable:channel:broadcasting_test:chat:Room#1-Campfire', event_name: :some_other_event)
    ChatChannel.broadcast_to(Room.new(1)).some_other_event
  end

  test "broadcasting_for with an object" do
    assert_equal "Room#1-Campfire", ChatChannel.broadcasting_for(Room.new(1))
  end

  test "broadcasting_for with an array" do
    assert_equal "Room#1-Campfire:Room#2-Campfire", ChatChannel.broadcasting_for([ Room.new(1), Room.new(2) ])
  end

  test "broadcasting_for with a string" do
    assert_equal "hello", ChatChannel.broadcasting_for("hello")
  end
end
