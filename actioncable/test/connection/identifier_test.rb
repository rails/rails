# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"
require "stubs/user"

class ActionCable::Connection::IdentifierTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    identified_by :current_user
    attr_reader :websocket

    public :process_internal_message

    def connect
      self.current_user = User.new "lifo"
    end
  end

  setup do
    @server = TestServer.new
  end

  test "connection identifier" do
    open_connection
    assert_equal "User#lifo", @connection.connection_identifier
  end

  test "should subscribe to internal channel on open and unsubscribe on close" do
    assert_called(@server.pubsub, :subscribe, [{ channel: "action_cable/User#lifo" }]) do
      open_connection
    end

    assert_called(@server.pubsub, :unsubscribe, [{ channel: "action_cable/User#lifo" }]) do
      @connection.handle_close
    end
  end

  test "processing disconnect message" do
    open_connection

    assert_called(@socket, :close) do
      @connection.process_internal_message "type" => "disconnect"
    end
  end

  test "processing invalid message" do
    open_connection

    assert_not_called(@socket, :close) do
      @connection.process_internal_message "type" => "unknown"
    end
  end

  private
    def open_connection
      env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket"

      @socket = ActionCable::Server::Socket.new(@server, env)
      @connection = Connection.new(@server, @socket).tap(&:handle_open)
    end
end
