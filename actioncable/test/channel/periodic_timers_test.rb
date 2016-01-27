require 'test_helper'
require 'stubs/test_connection'
require 'stubs/room'

class ActionCable::Channel::PeriodicTimersTest < ActiveSupport::TestCase
  class ChatChannel < ActionCable::Channel::Base
    periodically -> { ping }, every: 5
    periodically :send_updates, every: 1

    private
      def ping
      end
  end

  setup do
    @connection = TestConnection.new
  end

  test "periodic timers definition" do
    timers = ChatChannel.periodic_timers

    assert_equal 2, timers.size

    first_timer = timers[0]
    assert_kind_of Proc, first_timer[0]
    assert_equal 5, first_timer[1][:every]

    second_timer = timers[1]
    assert_equal :send_updates, second_timer[0]
    assert_equal 1, second_timer[1][:every]
  end

  test "timer start and stop" do
    EventMachine::PeriodicTimer.expects(:new).times(2).returns(true)
    channel = ChatChannel.new @connection, "{id: 1}", { id: 1 }

    channel.expects(:stop_periodic_timers).once
    channel.unsubscribe_from_channel
  end
end
