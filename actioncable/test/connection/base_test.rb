require 'test_helper'
require 'stubs/test_server'

class ActionCable::Connection::BaseTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    attr_reader :websocket, :subscriptions, :message_buffer, :connected

    def connect
      @connected = true
    end

    def disconnect
      @connected = false
    end

    def send_async(method, *args)
      # Bypass Celluloid
      send method, *args
    end
  end

  setup do
    @server = TestServer.new
    @server.config.allowed_request_origins = %w( http://rubyonrails.com )
  end

  test "making a connection with invalid headers" do
    run_in_eventmachine do
      connection = ActionCable::Connection::Base.new(@server, Rack::MockRequest.env_for("/test"))
      response = connection.process
      assert_equal 404, response[0]
    end
  end

  test "websocket connection" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      assert connection.websocket.possible?
      assert connection.websocket.alive?
    end
  end

  test "rack response" do
    run_in_eventmachine do
      connection = open_connection
      response = connection.process

      assert_equal [ -1, {}, [] ], response
    end
  end

  test "on connection open" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      connection.websocket.expects(:transmit).with(regexp_matches(/\_ping/))
      connection.message_buffer.expects(:process!)

      # Allow EM to run on_open callback
      EM.next_tick do
        assert_equal [ connection ], @server.connections
        assert connection.connected
      end
    end
  end

  test "on connection close" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      # Setup the connection
      EventMachine.stubs(:add_periodic_timer).returns(true)
      connection.send :on_open
      assert connection.connected

      connection.subscriptions.expects(:unsubscribe_from_all)
      connection.send :on_close

      assert ! connection.connected
      assert_equal [], @server.connections
    end
  end

  test "connection statistics" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      statistics = connection.statistics

      assert statistics[:identifier].blank?
      assert_kind_of Time, statistics[:started_at]
      assert_equal [], statistics[:subscriptions]
    end
  end

  test "explicitly closing a connection" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      connection.websocket.expects(:close)
      connection.close
    end
  end

  private
    def open_connection
      env = Rack::MockRequest.env_for "/test", 'HTTP_CONNECTION' => 'upgrade', 'HTTP_UPGRADE' => 'websocket',
        'HTTP_ORIGIN' => 'http://rubyonrails.com'

      Connection.new(@server, env)
    end
end
