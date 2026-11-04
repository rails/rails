# frozen_string_literal: true

require "test_helper"
require "stubs/test_socket"
require "stubs/room"
require "active_support/time"

class ActionCable::Channel::PeriodicTimersTest < ActionCable::TestCase
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
    @connection = TestSocket.new
  end

  test "periodic timers definition" do
    timers = ChatChannel.periodic_timers

    assert_equal 3, timers.size

    timers.each_with_index do |timer, i|
      assert_kind_of Proc, timer[0]
      assert_equal i + 1, timer[1][:every]
    end
  end

  test "disallow negative and zero periods" do
    [ 0, 0.0, 0.seconds, -1, -1.seconds, "foo", :foo, Object.new ].each do |invalid|
      e = assert_raise ArgumentError do
        ChatChannel.periodically :send_updates, every: invalid
      end
      assert_match(/Expected every:/, e.message)
    end
  end

  test "disallow block and arg together" do
    e = assert_raise ArgumentError do
      ChatChannel.periodically(:send_updates, every: 1) { ping }
    end
    assert_match(/not both/, e.message)
  end

  test "disallow unknown args" do
    [ "send_updates", Object.new, nil ].each do |invalid|
      e = assert_raise ArgumentError do
        ChatChannel.periodically invalid, every: 1
      end
      assert_match(/Expected a Symbol/, e.message)
    end
  end

  test "timer start and stop" do
    mock = Minitest::Mock.new
    3.times { mock.expect(:shutdown, nil) }

    assert_called(
      @connection.server.executor,
      :timer,
      times: 3,
      returns: mock
    ) do
      channel = ChatChannel.new @connection, "{id: 1}", id: 1

      channel.subscribe_to_channel
      channel.unsubscribe_from_channel
      assert_equal [], channel.send(:active_periodic_timers)
    end

    assert mock.verify
  end

  class QueueingSocket < TestSocket
    def queued_work
      @queued_work ||= []
    end

    def perform_work(receiver, method, *args)
      queued_work << -> { receiver.send method, *args }
    end
  end

  class TickingChannel < ActionCable::Channel::Base
    periodically every: 1 do
      ticks << :tick
    end

    def ticks
      @ticks ||= []
    end
  end

  test "timer skips a tick while the previous tick is still waiting to run" do
    socket = QueueingSocket.new
    tick = nil

    socket.server.executor.stub(:timer, ->(_every, &block) { tick = block; Minitest::Mock.new }) do
      channel = TickingChannel.new socket, "{id: 1}", id: 1
      channel.subscribe_to_channel

      3.times { tick.call }
      assert_equal 1, socket.queued_work.size

      socket.queued_work.shift.call
      assert_equal [ :tick ], channel.ticks

      tick.call
      assert_equal 1, socket.queued_work.size
    end
  end

  test "timer posts the next tick after the previous tick raised" do
    socket = QueueingSocket.new
    tick = nil

    socket.server.executor.stub(:timer, ->(_every, &block) { tick = block; Minitest::Mock.new }) do
      channel = TickingChannel.new socket, "{id: 1}", id: 1
      channel.subscribe_to_channel
      channel.define_singleton_method(:ticks) { raise "boom" }

      tick.call
      assert_raise(RuntimeError) { socket.queued_work.shift.call }

      tick.call
      assert_equal 1, socket.queued_work.size
    end
  end
end
