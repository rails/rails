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

  test "on connection close" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      # Set up the connection
      connection.send :handle_open
      assert connection.connected

      assert_called(connection.subscriptions, :unsubscribe_from_all) do
        connection.send :handle_close
      end

      assert_not connection.connected
      assert_equal [], @server.connections
    end
  end

  test "connection statistics" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      statistics = connection.statistics

      assert_predicate statistics[:identifier], :blank?
      assert_kind_of Time, statistics[:started_at]
      assert_equal [], statistics[:subscriptions]
      assert_kind_of Time, statistics[:last_message_received_at]
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

  test "closing a connection when it's expecting a PONG but it didn't receive one in time" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      connection.instance_variable_set(:@expects_pong, true)
      connection.instance_variable_set(:@last_message_received_at, 1.hour.ago)

      assert_called(connection.websocket, :close) do
        connection.beat
      end
    end
  end

  test "processing of an incomping PONG message" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      wait_for_async

      websocket_message = { type: "pong", message: 1.second.ago.to_f }.to_json

      notification_data = nil
      callback = ->(_name, _started, _finished, _unique_id, data) do
        notification_data = data
      end

      ActiveSupport::Notifications.subscribed(callback, "connection_latency.action_cable") do
        connection.receive(websocket_message)
      end

      assert_predicate notification_data[:value], :positive?
      assert_in_delta 1, notification_data[:value], 0.5
    end
  end

  test "receiving a message updates the last message received at timestamp" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      wait_for_async

      connection.instance_variable_set(:@last_message_received_at, 1.hour.ago)

      connection.receive({ type: "pong", message: 123.456 }.to_json)

      assert_in_delta Time.now, connection.instance_variable_get(:@last_message_received_at), 1
    end
  end

  private
    def open_connection
      env = Rack::MockRequest.env_for "/test", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"

      Connection.new(@server, env)
    end
end
