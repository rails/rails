# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"

class ActionCable::Connection::AuthorizationTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    attr_reader :raw_conn

    def connect
      reject_unauthorized_connection
    end
  end

  test "unauthorized connection" do
    connection = open_connection

    assert_called_with(connection.raw_conn, :transmit, [{ type: "disconnect", reason: "unauthorized", reconnect: false }]) do
      assert_called(connection.raw_conn, :close) do
        connection.handle_open
      end
    end
  end

  private
    def open_connection
      server = TestServer.new
      env = Rack::MockRequest.env_for "/test", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"

      raw_conn = ActionCable::Server::Connection.new(server, env)
      Connection.new(server, raw_conn)
    end
end
