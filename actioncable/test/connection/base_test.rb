# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"
require "active_support/core_ext/object/json"

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

      assert_predicate connection.websocket, :possible?

      wait_for_async
      assert_predicate connection.websocket, :alive?
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

      assert_called_with(connection.websocket, :transmit, [{ type: "welcome" }.to_json]) do
        assert_called(connection.message_buffer, :process!) do
          connection.process
          wait_for_async
        end
      end

      assert_equal [ connection ], @server.connections
      assert connection.connected
    end
  end

  test "notification for connect" do
    events = []
    ActiveSupport::Notifications.subscribe "connect.action_cable" do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    run_in_eventmachine do
      connection = open_connection
      connection.process

      assert_equal 1, events.length
      assert_equal "connect.action_cable", events[0].name
      assert_equal "ActionCable::Connection::BaseTest::Connection", events[0].payload[:connection_class]
      assert_equal connection.env, events[0].payload[:request].env
    end
  ensure
    ActiveSupport::Notifications.unsubscribe "perform_action.action_cable"
  end

  test "on connection close" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      # Setup the connection
      connection.send :handle_open
      assert connection.connected

      assert_called(connection.subscriptions, :unsubscribe_from_all) do
        connection.send :handle_close
      end

      assert_not connection.connected
      assert_equal [], @server.connections
    end
  end

  test "notification for disconnect" do
    events = []
    ActiveSupport::Notifications.subscribe "disconnect.action_cable" do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    run_in_eventmachine do
      connection = open_connection
      connection.process
      connection.send :handle_open
      connection.send :handle_close

      assert_equal 1, events.length
      assert_equal "disconnect.action_cable", events[0].name
      assert_equal "ActionCable::Connection::BaseTest::Connection", events[0].payload[:connection_class]
      assert_equal connection.env, events[0].payload[:request].env
    end
  ensure
    ActiveSupport::Notifications.unsubscribe "perform_action.action_cable"
  end

  test "connection statistics" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      statistics = connection.statistics

      assert_predicate statistics[:identifier], :blank?
      assert_kind_of Time, statistics[:started_at]
      assert_equal [], statistics[:subscriptions]
    end
  end

  test "explicitly closing a connection" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      assert_called(connection.websocket, :close) do
        connection.close(reason: "testing")
      end
    end
  end

  test "rejecting a connection causes a 404" do
    run_in_eventmachine do
      class CallMeMaybe
        def call(*)
          raise "Do not call me!"
        end
      end

      env = Rack::MockRequest.env_for(
        "/test",
        "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
          "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.org", "rack.hijack" => CallMeMaybe.new
      )

      connection = ActionCable::Connection::Base.new(@server, env)
      response = connection.process
      assert_equal 404, response[0]
    end
  end

  private
    def open_connection
      env = Rack::MockRequest.env_for "/test", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"

      Connection.new(@server, env)
    end
end
