# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"
require "active_support/core_ext/hash/indifferent_access"

class BaseTest < ActionCable::TestCase
  def setup
    @server = ActionCable::Server::Base.new
    @server.config.cable = { adapter: "async" }.with_indifferent_access
  end

  class FakeConnection
    def close
    end
  end

  test "#restart closes all open connections" do
    conn = FakeConnection.new
    @server.add_connection(conn)

    assert_called(conn, :close) do
      @server.restart
    end
  end

  class ClosableConnection
    def close(*); end
  end

  test "#restart clears the connections registry" do
    @server.add_connection(ClosableConnection.new)
    assert_equal 1, @server.connections.size

    @server.restart

    # remove_connection normally runs via the worker pool, which restart halts,
    # so the closed connections must be dropped here or they leak (e.g. on every
    # dev-mode code reload, which calls restart on the singleton server).
    assert_empty @server.connections
  end

  test "#each_connection iterates a snapshot so connections can be added during iteration" do
    beating = Class.new do
      def initialize(server)
        @server = server
      end

      def beat
        @server.add_connection(Object.new)
      end
    end.new(@server)

    @server.add_connection(beating)

    # A connection completing its handshake (add_connection) on a worker thread
    # while the 3s heartbeat iterates the live connections must not raise
    # "can't add a new key into hash during iteration".
    assert_nothing_raised do
      @server.each_connection(&:beat)
    end
  end

  test "#restart shuts down worker pool" do
    assert_called(@server.worker_pool, :halt) do
      @server.restart
    end
  end

  test "#restart shuts down pub/sub adapter" do
    assert_called(@server.pubsub, :shutdown) do
      @server.restart
    end
  end

  test "#restart shuts down the heartbeat timer" do
    @server.send(:setup_heartbeat_timer)
    timer = @server.instance_variable_get(:@heartbeat_timer)
    assert_predicate timer, :running?

    @server.restart

    assert_not timer.running?
    assert_nil @server.instance_variable_get(:@heartbeat_timer)
  end
end
