# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "socket"
require "active_support/core_ext/object/with"

class ActionCable::Server::StreamEventLoopTest < ActionCable::TestCase
  class TestStream
    def receive(data); end
    def close; end
    def flush_write_buffer = true
  end

  setup do
    @event_loop = ActionCable::Server::StreamEventLoop.new
    @io, @client_io = Socket.pair(:UNIX, :STREAM)
  end

  teardown do
    @event_loop.stop
    @client_io.close
  end

  test "detach closes the socket when it can't be deregistered" do
    Thread.with(report_on_exception: false) do
      @event_loop.attach(@io, TestStream.new)
      selector = @event_loop.instance_variable_get(:@nio)
      Timeout.timeout(5) { sleep 0.01 until selector.registered?(@io) }

      selector.stub(:deregister, proc { raise ArgumentError, "mode not supported" }) do
        @event_loop.detach(@io)
        Timeout.timeout(5) { sleep 0.01 until @io.closed? }
      end
    end

    assert_predicate @io, :closed?
  end
end
