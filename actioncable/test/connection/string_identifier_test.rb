require "test_helper"
require "stubs/test_server"

class ActionCable::Connection::StringIdentifierTest < ActionCable::TestCase
  class Socket < ActionCable::Socket::Base
    def send_async(method, *args)
      send method, *args
    end
  end

  class Connection < ActionCable::Connection::Base
    identified_by :current_token

    def connect
      self.current_token = "random-string"
    end
  end

  test "connection identifier" do
    run_in_eventmachine do
      open_socket_with_stubbed_pubsub
      assert_equal "random-string", @connection.identifier
    end
  end

  private
    def open_socket_with_stubbed_pubsub
      @server = TestServer.new(connection_class: Connection)
      @server.stubs(:pubsub).returns(stub_everything("pubsub"))

      open_socket
    end

    def open_socket
      env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket"
      @socket = Socket.new(@server, env)
      @connection = @socket.connection

      @socket.process
      @socket.send :on_open
    end

    def close_socket
      @socket.send :on_close
    end
end
