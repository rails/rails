# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"
require "active_support/core_ext/object/json"

class ActionCable::Connection::BaseTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    attr_reader :subscriptions, :connected
    # Make this method public so we can test it
    attr_reader :socket

    def connect
      @connected = true
    end

    def disconnect
      @connected = false
    end
  end

  test "on connection open" do
    connection = open_connection

    assert_called_with(connection.socket, :transmit, [{ type: "welcome" }]) do
      connection.handle_open
    end

    assert connection.connected
  end

  test "on connection close" do
    connection = open_connection

    # Set up the connection
    connection.handle_open
    assert connection.connected

    assert_called(connection.subscriptions, :unsubscribe_from_all) do
      connection.handle_close
    end

    assert_not connection.connected
  end

  test "connection statistics" do
    connection = open_connection
    connection.handle_open

    statistics = connection.statistics

    assert_predicate statistics[:identifier], :blank?
    assert_kind_of Time, statistics[:started_at]
    assert_equal [], statistics[:subscriptions]
  end

  test "explicitly closing a connection" do
    connection = open_connection

    assert_called(connection.socket, :close) do
      assert_called(connection.socket, :transmit, [{ type: "disconnect", reason: "testing", reconnect: true }]) do
        connection.close(reason: "testing")
      end
    end
  end

  private
    def open_connection
      server = TestServer.new
      env = Rack::MockRequest.env_for "/test", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"

      socket = ActionCable::Server::Socket.new(server, env)
      Connection.new(server, socket)
    end
end
