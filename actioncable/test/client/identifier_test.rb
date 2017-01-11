require "test_helper"
require "stubs/test_server"
require "stubs/user"

class ActionCable::Connection::IdentifierTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
  end

  class Client < ActionCable::Client::Base
    identified_by :current_user

    public :process_internal_message

    def connect
      self.current_user = User.new "lifo"
    end
  end

  test "connection identifier" do
    run_in_eventmachine do
      open_connection_with_stubbed_pubsub
      assert_equal "User#lifo", @connection.client.identifier
    end
  end

  test "should subscribe to internal channel on open and unsubscribe on close" do
    run_in_eventmachine do
      pubsub = mock("pubsub_adapter")
      pubsub.expects(:subscribe).with("action_cable/User#lifo", kind_of(Proc), kind_of(Proc))
      pubsub.expects(:unsubscribe).with("action_cable/User#lifo", kind_of(Proc))

      server = TestServer.new(connection_class: Client)
      server.stubs(:pubsub).returns(pubsub)

      open_connection server: server
      close_connection
    end
  end

  test "processing disconnect message" do
    run_in_eventmachine do
      open_connection_with_stubbed_pubsub

      @connection.expects(:close)
      @client.process_internal_message "type" => "disconnect"
    end
  end

  test "processing invalid message" do
    run_in_eventmachine do
      open_connection_with_stubbed_pubsub

      @connection.expects(:close).never
      @client.process_internal_message "type" => "unknown"
    end
  end

  private
    def open_connection_with_stubbed_pubsub
      server = TestServer.new(connection_class: Client)
      server.stubs(:adapter).returns(stub_everything("adapter"))

      open_connection server: server
    end

    def open_connection(server:)
      env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket"
      @connection = Connection.new(server, env)
      @client = @connection.client

      @connection.process
      @connection.send :handle_open
    end

    def close_connection
      @connection.send :handle_close
    end
end
