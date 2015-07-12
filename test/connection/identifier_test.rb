require 'test_helper'
require 'stubs/test_server'
require 'stubs/user'

class ActionCable::Connection::IdentifierTest < ActiveSupport::TestCase
  class Connection < ActionCable::Connection::Base
    identified_by :current_user
    attr_reader :websocket

    public :process_internal_message

    def connect
      self.current_user = User.new "lifo"
    end
  end

  setup do
    @server = TestServer.new

    env = Rack::MockRequest.env_for "/test", 'HTTP_CONNECTION' => 'upgrade', 'HTTP_UPGRADE' => 'websocket'
    @connection = Connection.new(@server, env)
  end

  test "connection identifier" do
    open_connection_with_stubbed_pubsub
    assert_equal "User#lifo", @connection.connection_identifier
  end

  test "should subscribe to internal channel on open" do
    pubsub = mock('pubsub')
    pubsub.expects(:subscribe).with('action_cable/User#lifo')
    @server.expects(:pubsub).returns(pubsub)

    open_connection
  end

  test "should unsubscribe from internal channel on close" do
    open_connection_with_stubbed_pubsub

    pubsub = mock('pubsub')
    pubsub.expects(:unsubscribe_proc).with('action_cable/User#lifo', kind_of(Proc))
    @server.expects(:pubsub).returns(pubsub)

    close_connection
  end

  test "processing disconnect message" do
    open_connection_with_stubbed_pubsub

    @connection.websocket.expects(:close)
    message = { 'type' => 'disconnect' }.to_json
    @connection.process_internal_message message
  end

  test "processing invalid message" do
    open_connection_with_stubbed_pubsub

    @connection.websocket.expects(:close).never
    message = { 'type' => 'unknown' }.to_json
    @connection.process_internal_message message
  end

  protected
    def open_connection_with_stubbed_pubsub
      @server.stubs(:pubsub).returns(stub_everything('pubsub'))
      open_connection
    end

    def open_connection
      @connection.process
      @connection.send :on_open
    end

    def close_connection
      @connection.send :on_close
    end
end
