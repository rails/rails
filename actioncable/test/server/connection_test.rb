# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"
require "active_support/core_ext/object/json"

class ActionCable::Server::ConnectionTest < ActionCable::TestCase
  class Connection
    attr_reader :last_message, :raw_conn, :connected

    def initialize(_server, conn)
      @raw_conn = conn
    end

    def handle_open
      @connected = true
      raw_conn.transmit type: "test"
    end

    def handle_close
      @connected = false
    end

    def handle_incoming(payload)
      @last_message = payload
    end
  end

  setup do
    @server = TestServer.new
    @server.config.allowed_request_origins = %w( http://rubyonrails.com )
    @server.config.connection_class = -> { Connection }
  end

  test "making a connection with invalid headers" do
    run_in_eventmachine do
      connection = ActionCable::Server::Connection.new(@server, Rack::MockRequest.env_for("/test"))
      response = connection.process
      assert_equal 404, response[0]
    end
  end

  test "websocket connection" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      ws = connection.send(:websocket)

      assert_predicate ws, :possible?

      wait_for_async
      assert_predicate ws, :alive?
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

      ws = connection.send(:websocket)
      mb = connection.send(:message_buffer)

      assert_called_with(ws, :transmit, [{ type: "test" }.to_json]) do
        assert_called(mb, :process!) do
          connection.process
          wait_for_async
        end
      end

      assert_equal [ connection.app_conn ], @server.connections
      assert connection.app_conn.connected
    end
  end

  test "on connection receive" do
    run_in_eventmachine do
      connection = open_connection
      connection.process
      wait_for_async

      connection.receive({ message: "hello" }.to_json)
      wait_for_async

      assert_equal({ "message" => "hello" }, connection.app_conn.last_message)
    end
  end

  test "on connection close" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      connection.send :handle_open
      assert connection.app_conn.connected

      connection.send :handle_close
      assert_not connection.app_conn.connected

      assert_equal [], @server.connections
    end
  end

  test "explicitly closing a connection" do
    run_in_eventmachine do
      connection = open_connection
      connection.process

      ws = connection.send(:websocket)

      assert_called(ws, :close) do
        connection.close
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

      connection = ActionCable::Server::Connection.new(@server, env)
      response = connection.process
      assert_equal 404, response[0]
    end
  end

  private
    def open_connection
      env = Rack::MockRequest.env_for "/test", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"

      ActionCable::Server::Connection.new(@server, env)
    end
end
