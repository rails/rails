require 'test_helper'
require 'stubs/test_server'

class ActionCable::Connection::BaseTest < ActiveSupport::TestCase
  class Connection < ActionCable::Connection::Base
    attr_reader :websocket, :heartbeat, :subscriptions, :message_buffer, :connected

    def connect
      @connected = true
    end

    def disconnect
      @connected = false
    end
  end

  setup do
    @server = TestServer.new
    @server.config.disable_request_forgery_protection = true

    env = Rack::MockRequest.env_for "/test", 'HTTP_CONNECTION' => 'upgrade', 'HTTP_UPGRADE' => 'websocket'
    @connection = Connection.new(@server, env)
    @response = @connection.process
  end

  test "making a connection with invalid headers" do
    connection = ActionCable::Connection::Base.new(@server, Rack::MockRequest.env_for("/test"))
    response = connection.process
    assert_equal 404, response[0]
  end

  test "websocket connection" do
    assert @connection.websocket.possible?
    assert @connection.websocket.alive?
  end

  test "rack response" do
    assert_equal [ -1, {}, [] ], @response
  end

  test "on connection open" do
    assert ! @connection.connected

    EventMachine.expects(:add_periodic_timer)
    @connection.websocket.expects(:transmit).with(regexp_matches(/\_ping/))
    @connection.message_buffer.expects(:process!)

    @connection.send :on_open

    assert_equal [ @connection ], @server.connections
    assert @connection.connected
  end

  test "on connection close" do
    # Setup the connection
    EventMachine.stubs(:add_periodic_timer).returns(true)
    @connection.send :on_open
    assert @connection.connected

    EventMachine.expects(:cancel_timer)
    @connection.subscriptions.expects(:unsubscribe_from_all)
    @connection.send :on_close

    assert ! @connection.connected
    assert_equal [], @server.connections
  end

  test "connection statistics" do
    statistics = @connection.statistics

    assert statistics[:identifier].blank?
    assert_kind_of Time, statistics[:started_at]
    assert_equal [], statistics[:subscriptions]
  end

  test "explicitly closing a connection" do
    @connection.websocket.expects(:close)
    @connection.close
  end
end
