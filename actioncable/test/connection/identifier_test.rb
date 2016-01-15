require 'test_helper'
require 'stubs/test_server'
require 'stubs/user'

class ActionCable::Connection::IdentifierTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    identified_by :current_user
    attr_reader :websocket

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
      adapter = mock('adapter')
      adapter.expects(:subscribe).with('action_cable/User#lifo', kind_of(Proc))
      adapter.expects(:unsubscribe).with('action_cable/User#lifo', kind_of(Proc))

      server = TestServer.new
      server.stubs(:adapter).returns(adapter)

      open_connection server: server
      close_connection
    end
  end

  test "processing disconnect message" do
    run_in_eventmachine do
      open_connection_with_stubbed_pubsub

      @connection.websocket.expects(:close)
      message = ActiveSupport::JSON.encode('type' => 'disconnect')
      @connection.process_internal_message message
    end
  end

  test "processing invalid message" do
    run_in_eventmachine do
      open_connection_with_stubbed_pubsub

      @connection.websocket.expects(:close).never
      message = ActiveSupport::JSON.encode('type' => 'unknown')
      @connection.process_internal_message message
    end
  end

  protected
    def open_connection_with_stubbed_pubsub
      server = TestServer.new
      server.stubs(:adapter).returns(stub_everything('adapter'))

      open_connection server: server
    end

    def open_connection(server:)
      env = Rack::MockRequest.env_for "/test", 'HTTP_CONNECTION' => 'upgrade', 'HTTP_UPGRADE' => 'websocket'
      @connection = Connection.new(server, env)

      @connection.process
      @connection.send :on_open
    end

    def close_connection
      @connection.send :on_close
    end
end
