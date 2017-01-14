require "test_helper"
require "stubs/test_server"
require "stubs/user"

class ActionCable::Connection::MultipleIdentifiersTest < ActionCable::TestCase
  class Socket < ActionCable::Socket::Base
  end

  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_room

    def connect
      self.current_user = User.new "lifo"
      self.current_room = Room.new "my", "room"
    end
  end

  test "multiple connection identifiers" do
    run_in_eventmachine do
      open_socket_with_stubbed_pubsub
      assert_equal "Room#my-room:User#lifo", @connection.identifier
    end
  end

  private
    def open_socket_with_stubbed_pubsub
      server = TestServer.new(connection_class: Connection)
      server.stubs(:pubsub).returns(stub_everything("pubsub"))

      open_socket server: server
    end

    def open_socket(server:)
      env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket"
      @socket = Socket.new(server, env)
      @connection = @socket.connection

      @socket.process
      @socket.send :handle_open
    end

    def close_socket
      @socket.send :handle_close
    end
end
