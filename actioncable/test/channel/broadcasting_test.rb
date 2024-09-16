# frozen_string_literal: true

require "test_helper"
require "stubs/test_connection"
require "stubs/room"

class ActionCable::Channel::BroadcastingTest < ActionCable::TestCase
  class ChatChannel < ActionCable::Channel::Base
  end

  setup do
    @connection = TestConnection.new
  end

  test "broadcasts_to" do
    assert_called_with(
      ActionCable.server,
      :broadcast,
      [
        "action_cable:channel:broadcasting_test:chat:Room#1Campfire",
        "Hello World"
      ]
    ) do
      ChatChannel.broadcast_to(Room.new(1), "Hello World")
    end
  end

  test "broadcast_to_list" do
    assert_called_with(
      ActionCable.server,
      :broadcast_list,
      [
        "action_cable:channel:broadcasting_test:chat:Room#1Campfire",
        "Hello World"
      ]
    ) do
      ChatChannel.broadcast_to_list(Room.new(1), "Hello World")
    end
  end

  test "broadcasting_for with an object" do
    assert_equal(
      "action_cable:channel:broadcasting_test:chat:Room#1Campfire",
      ChatChannel.broadcasting_for(Room.new(1))
    )
  end

  test "broadcasting_for with an array" do
    assert_equal(
      "action_cable:channel:broadcasting_test:chat:Room#1Campfire:Room#2Campfire",
      ChatChannel.broadcasting_for([ Room.new(1), Room.new(2) ])
    )
  end

  test "broadcasting_for with a string" do
    assert_equal(
      "action_cable:channel:broadcasting_test:chat:hello",
      ChatChannel.broadcasting_for("hello")
    )
  end

  test "broadcasting_for_list with an array of objects" do
    assert_equal(
      "action_cable:channel:broadcasting_test:chat:Room#1Campfire-Room#2Campfire",
      ChatChannel.broadcasting_for_list([ Room.new(1), Room.new(2) ])
    )
  end

  test "broadcasting_for_list with an of objects and string" do
    assert_equal(
      "action_cable:channel:broadcasting_test:chat:Room#1Campfire-Room#2Campfire-hello",
      ChatChannel.broadcasting_for_list([ Room.new(1), Room.new(2), "hello" ])
    )
  end

  test "broadcasting_for_list with an of objects and string with a dash" do
    assert_raises(ArgumentError) do
      ChatChannel.broadcasting_for_list([ Room.new(1), Room.new(2), "hello-world" ])
    end
  end
end
