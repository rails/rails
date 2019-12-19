# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"

class ActionCable::Connection::StringIdentifierTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    identified_by :current_token

    def connect
      self.current_token = "random-string"
    end

    def send_async(method, *args)
      send method, *args
    end
  end

  test "connection identifier" do
    run_in_eventmachine do
      open_connection

      assert_equal "random-string", @connection.connection_identifier
    end
  end

  private
    def open_connection
      server = TestServer.new
      env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket"
      @connection = Connection.new(server, env)

      @connection.process
      @connection.send :on_open
    end
end
