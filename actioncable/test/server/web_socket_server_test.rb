# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"
require "active_support/core_ext/hash/indifferent_access"

class WebSocketServerTest < ActionCable::TestCase
  def setup
    @server = ActionCable::Server::Base.new
    @ws_server = ActionCable::Server::WebSocketServer.new(@server)
  end

  class FakeConnection
    def close
    end
  end

  test "#restart shuts down worker pool" do
    assert_called(@ws_server.worker_pool, :halt) do
      @ws_server.restart
    end
  end

  test "#restart shuts down the heartbeat timer" do
    @ws_server.send(:setup_heartbeat_timer)
    timer = @ws_server.instance_variable_get(:@heartbeat_timer)
    assert_predicate timer, :running?

    @ws_server.restart

    assert_not timer.running?
    assert_nil @ws_server.instance_variable_get(:@heartbeat_timer)
  end
end
