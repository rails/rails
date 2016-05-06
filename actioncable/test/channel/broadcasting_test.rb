require 'test_helper'
require 'stubs/test_connection'
require 'stubs/room'

class ActionCable::Channel::BroadcastingTest < ActiveSupport::TestCase
  setup do
    @connection = TestConnection.new
  end

  test "broadcasts_to" do
    ActionCable.stubs(:server).returns mock().tap { |m| m.expects(:broadcast).with('test:Room#1-Campfire', "Hello World") }
    TestChannel.broadcast_to(Room.new(1), "Hello World")
  end

  test "broadcasting_for with an object" do
    assert_equal "Room#1-Campfire", TestChannel.broadcasting_for(Room.new(1))
  end

  test "broadcasting_for with an array" do
    assert_equal "Room#1-Campfire:Room#2-Campfire", TestChannel.broadcasting_for([ Room.new(1), Room.new(2) ])
  end

  test "broadcasting_for with a string" do
    assert_equal "hello", TestChannel.broadcasting_for("hello")
  end
end
