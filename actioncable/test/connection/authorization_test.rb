# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"

class ActionCable::Connection::AuthorizationTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    attr_reader :websocket

    def connect
      reject_unauthorized_connection
    end

    def send_async(method, *args)
      send method, *args
    end
  end

  test "unauthorized connection" do
    run_in_eventmachine do
      server = TestServer.new
      server.config.allowed_request_origins = %w( http://rubyonrails.com )

      env = Rack::MockRequest.env_for "/test", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"

      connection = Connection.new(server, env)
      connection.websocket.expects(:close)

      connection.process
    end
  end
end
