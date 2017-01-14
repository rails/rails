require "test_helper"
require "stubs/test_server"

class ActionCable::Connection::AuthorizationTest < ActionCable::TestCase
  class Socket < ActionCable::Socket::Base
    attr_reader :websocket

    def send_async(method, *args)
      send method, *args
    end
  end

  class Connection < ActionCable::Connection::Base
    def connect
      reject_unauthorized_connection
    end
  end

  test "unauthorized connection" do
    run_in_eventmachine do
      server = TestServer.new(connection_class: Connection)
      server.config.allowed_request_origins = %w( http://rubyonrails.com )

      env = Rack::MockRequest.env_for "/test", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"

      socket = Socket.new(server, env)
      socket.websocket.expects(:close)

      socket.process
    end
  end
end
