# frozen_string_literal: true

require "test_helper"
require "stubs/test_socket"
require "stubs/room"

class ActionCable::Channel::BroadcastingTest < ActionCable::TestCase
  class ChatChannel < ActionCable::Channel::Base
  end

  setup do
    @connection = TestSocket.new
  end

  test "broadcasts_to" do
    assert_called_with(
      ActionCable.server,
      :broadcast,
      [
        "action_cable:channel:broadcasting_test:chat:Room#1-Campfire",
        "Hello World"
      ]
    ) do
      ChatChannel.broadcast_to(Room.new(1), "Hello World")
    end
  end

  test "broadcasting_for with an object" do
    assert_equal(
      "action_cable:channel:broadcasting_test:chat:Room#1-Campfire",
      ChatChannel.broadcasting_for(Room.new(1))
    )
  end

  test "broadcasting_for with an array" do
    assert_equal(
      "action_cable:channel:broadcasting_test:chat:Room#1-Campfire:Room#2-Campfire",
      ChatChannel.broadcasting_for([ Room.new(1), Room.new(2) ])
    )
  end

  test "broadcasting_for with a string" do
    assert_equal(
      "action_cable:channel:broadcasting_test:chat:hello",
      ChatChannel.broadcasting_for("hello")
    )
  end
end
