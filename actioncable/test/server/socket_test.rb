# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"
require "active_support/core_ext/object/json"

class ActionCable::Server::SocketTest < ActionCable::TestCase
  class Connection
    attr_reader :last_message, :socket, :connected

    def initialize(_server, socket)
      @socket = socket
    end

    def handle_open
      @connected = true
      socket.transmit type: "test"
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
      socket = ActionCable::Server::Socket.new(@server, Rack::MockRequest.env_for("/test"))
      response = socket.process
      assert_equal 404, response[0]
    end
  end

  test "websocket connection" do
    run_in_eventmachine do
      socket = open_socket
      socket.process

      ws = socket.send(:websocket)

      assert_predicate ws, :possible?

      wait_for_async
      assert_predicate ws, :alive?
    end
  end

  test "rack response" do
    run_in_eventmachine do
      socket = open_socket
      response = socket.process

      assert_equal [ -1, {}, [] ], response
    end
  end

  test "on connection open" do
    run_in_eventmachine do
      socket = open_socket

      ws = socket.send(:websocket)
      mb = socket.send(:message_buffer)

      assert_called_with(ws, :transmit, [{ type: "test" }.to_json]) do
        assert_called(mb, :process!) do
          socket.process
          wait_for_async
        end
      end

      assert_equal [ socket.connection ], @server.connections
      assert socket.connection.connected
    end
  end

  test "on connection receive" do
    run_in_eventmachine do
      socket = open_socket
      socket.process
      wait_for_async

      socket.receive({ message: "hello" }.to_json)
      wait_for_async

      assert_equal({ "message" => "hello" }, socket.connection.last_message)
    end
  end

  test "on connection close" do
    run_in_eventmachine do
      socket = open_socket
      socket.process

      socket.send :handle_open
      assert socket.connection.connected

      socket.send :handle_close
      assert_not socket.connection.connected

      assert_equal [], @server.connections
    end
  end

  test "explicitly closing a connection" do
    run_in_eventmachine do
      socket = open_socket
      socket.process

      ws = socket.send(:websocket)

      assert_called(ws, :close) do
        socket.close
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

      socket = ActionCable::Server::Socket.new(@server, env)
      response = socket.process
      assert_equal 404, response[0]
    end
  end

  private
    def open_socket
      env = Rack::MockRequest.env_for "/test", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"

      ActionCable::Server::Socket.new(@server, env)
    end
end
