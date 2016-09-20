require "test_helper"
require "stubs/test_connection"
require "stubs/room"
require "active_support/time"

class ActionCable::Channel::PeriodicTimersTest < ActiveSupport::TestCase
  class ChatChannel < ActionCable::Channel::Base
    # Method name arg
    periodically :send_updates, every: 1

    # Proc arg
    periodically -> { ping }, every: 2

    # Block arg
    periodically every: 3 do
      ping
    end

    private
      def ping
      end
  end

  setup do
    @connection = TestConnection.new
  end

  test "periodic timers definition" do
    timers = ChatChannel.periodic_timers

    assert_equal 3, timers.size

    timers.each_with_index do |timer, i|
      assert_kind_of Proc, timer[0]
      assert_equal i+1, timer[1][:every]
    end
  end

  test "disallow negative and zero periods" do
    [ 0, 0.0, 0.seconds, -1, -1.seconds, "foo", :foo, Object.new ].each do |invalid|
      assert_raise ArgumentError, /Expected every:/ do
        ChatChannel.periodically :send_updates, every: invalid
      end
    end
  end

  test "disallow block and arg together" do
    assert_raise ArgumentError, /not both/ do
      ChatChannel.periodically(:send_updates, every: 1) { ping }
    end
  end

  test "disallow unknown args" do
    [ "send_updates", Object.new, nil ].each do |invalid|
      assert_raise ArgumentError, /Expected a Symbol/ do
        ChatChannel.periodically invalid, every: 1
      end
    end
  end

  test "timer start and stop" do
    @connection.server.event_loop.expects(:timer).times(3).returns(stub(shutdown: nil))
    channel = ChatChannel.new @connection, "{id: 1}", id: 1

    channel.subscribe_to_channel
    channel.unsubscribe_from_channel
    assert_equal [], channel.send(:active_periodic_timers)
  end
end
