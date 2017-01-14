require "test_helper"
require "stubs/test_server"
require "stubs/user"

class ActionCable::Connection::IdentifierTest < ActionCable::TestCase
  class Socket < ActionCable::Socket::Base
  end

  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    public :process_internal_message

    def connect
      self.current_user = User.new "lifo"
    end
  end

  test "connection identifier" do
    run_in_eventmachine do
      open_socket_with_stubbed_pubsub
      assert_equal "User#lifo", @socket.connection.identifier
    end
  end

  test "should subscribe to internal channel on open and unsubscribe on close" do
    run_in_eventmachine do
      pubsub = mock("pubsub_adapter")
      pubsub.expects(:subscribe).with("action_cable/User#lifo", kind_of(Proc), kind_of(Proc))
      pubsub.expects(:unsubscribe).with("action_cable/User#lifo", kind_of(Proc))

      server = TestServer.new(connection_class: Connection)
      server.stubs(:pubsub).returns(pubsub)

      open_socket server: server
      close_connection
    end
  end

  test "processing disconnect message" do
    run_in_eventmachine do
      open_socket_with_stubbed_pubsub

      @socket.expects(:close)
      @connection.process_internal_message "type" => "disconnect"
    end
  end

  test "processing invalid message" do
    run_in_eventmachine do
      open_socket_with_stubbed_pubsub

      @socket.expects(:close).never
      @connection.process_internal_message "type" => "unknown"
    end
  end

  private
    def open_socket_with_stubbed_pubsub
      server = TestServer.new(connection_class: Connection)
      server.stubs(:adapter).returns(stub_everything("adapter"))

      open_socket server: server
    end

    def open_socket(server:)
      env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket"
      @socket = Socket.new(server, env)
      @connection = @socket.connection

      @socket.process
      @socket.send :handle_open
    end

    def close_connection
      @socket.send :handle_close
    end
end
