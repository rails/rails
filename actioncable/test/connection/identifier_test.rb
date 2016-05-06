require 'test_helper'

class ActionCable::Connection::IdentifierTest < ActionCable::TestCase
  class Connection < TestConnection
    identified_by :current_user
    public :process_internal_message

    def connect
      self.current_user = User.new "lifo"
    end
  end

  test "connection identifier" do
    run_in_eventmachine do
      open_connection_with_stubbed_pubsub
      assert_equal "User#lifo", @connection.connection_identifier
    end
  end

  test "should subscribe to internal channel on open and unsubscribe on close" do
    run_in_eventmachine do
      pubsub = mock('pubsub_adapter')
      pubsub.expects(:subscribe).with('action_cable/User#lifo', kind_of(Proc))
      pubsub.expects(:unsubscribe).with('action_cable/User#lifo', kind_of(Proc))

      server = TestServer.new
      server.stubs(:pubsub).returns(pubsub)

      open_connection server: server
      close_connection
    end
  end

  test "processing disconnect message" do
    run_in_eventmachine do
      open_connection_with_stubbed_pubsub

      @connection.websocket.expects(:close)
      @connection.process_internal_message 'type' => 'disconnect'
    end
  end

  test "processing invalid message" do
    run_in_eventmachine do
      open_connection_with_stubbed_pubsub

      @connection.websocket.expects(:close).never
      @connection.process_internal_message 'type' => 'unknown'
    end
  end

  protected
    def open_connection_with_stubbed_pubsub
      server = TestServer.new
      server.stubs(:adapter).returns(stub_everything('adapter'))

      open_connection server: server
    end

    def open_connection(server:)
      @connection = Connection.new(server, default_env)

      @connection.process
      @connection.send :handle_open
    end

    def close_connection
      @connection.send :handle_close
    end
end
