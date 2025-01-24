# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"

class ActionCable::Connection::StringIdentifierTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    identified_by :current_token

    def connect
      self.current_token = "random-string"
    end
  end

  test "connection identifier" do
    open_connection

    assert_equal "random-string", @connection.connection_identifier
  end

  private
    def open_connection
      server = TestServer.new
      env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket"

      @socket = ActionCable::Server::Socket.new(server, env)
      @connection = Connection.new(server, @socket).tap(&:handle_open)
    end
end
