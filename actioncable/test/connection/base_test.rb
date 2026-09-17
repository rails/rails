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

  test "inspect does not show internals" do
    connection = open_connection
    assert_match(/\A#<ActionCable::Connection::BaseTest::Connection:0x[0-9a-f]+>\z/, connection.inspect)
  end

  test "socket is closed even when transmit raises during close" do
    connection = open_connection
    socket = connection.socket

    # Simulate a socket whose output queue has already been closed (e.g. after a
    # prior restart call), so that transmitting the disconnect message raises.
    socket.stub(:transmit, ->(*) { raise ClosedQueueError, "queue closed" }) do
      assert_called(socket, :close) do
        connection.close(reason: "server_restart")
      end
    end
  end

  test "on connection open confirms the negotiated extensions" do
    connection = open_connection

    connection.socket.stub(:extensions, ["pong"]) do
      assert_called_with(connection.socket, :transmit, [{ type: "welcome", extensions: ["pong"] }]) do
        connection.handle_open
      end
    end
  end

  test "beat sends pings" do
    connection = open_connection
    connection.handle_open

    freeze_time do
      connection.socket.stub(:unresponsive?, false) do
        assert_not_called(connection.socket, :close!) do
          assert_called_with(connection.socket, :transmit, [{ type: "ping", message: Time.now.to_i }]) do
            connection.beat
          end
        end
      end
    end
  end

  test "beat closes an unresponsive connection" do
    connection = open_connection
    connection.handle_open

    connection.socket.stub(:unresponsive?, true) do
      assert_called(connection.socket, :close!) do
        assert_called(connection.socket, :close) do
          assert_called_with(connection.socket, :transmit, [{ type: "disconnect", reason: "no_pong", reconnect: true }]) do
            connection.beat
          end
        end
      end
    end
  end

  test "on pong command" do
    connection = open_connection
    connection.handle_open

    pongs = []
    connection.stub(:handle_pong, ->(message) { pongs << message }) do
      assert_not_called(connection.subscriptions, :execute_command) do
        connection.handle_incoming("command" => "pong", "message" => 1234567890)
      end
    end

    assert_equal [1234567890], pongs
  end

  test "works with a socket that does not support pongs" do
    connection = Connection.new(ActionCable.server, TestSocket.new)

    assert_called_with(connection.socket, :transmit, [{ type: "welcome" }]) do
      connection.handle_open
    end

    freeze_time do
      assert_called_with(connection.socket, :transmit, [{ type: "ping", message: Time.now.to_i }]) do
        connection.beat
      end
    end
  end

  test "#broadcast" do
    connection = Connection.new(ActionCable.server, ActionCable::Server::Socket.new(ActionCable.server, {}))

    messages = capture_broadcasts("test") do
      connection.broadcast("test", { message: "hello" })
    end

    assert_equal 1, messages.size
    assert_equal({ "message" => "hello" }, messages.first)
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
