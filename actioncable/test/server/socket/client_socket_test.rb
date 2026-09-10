# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"

class ActionCable::Server::Socket::ClientSocketTest < ActionCable::TestCase
  class TestSocket < ActionCable::Server::Socket
    class TestConnection
      def initialize(socket)
        @socket = socket
      end

      def handle_open = @socket.connect

      def handle_close = @socket.disconnect
    end

    attr_reader :connected, :websocket, :errors

    def initialize(*)
      super
      @errors = []
      @connection = TestConnection.new(self)
    end

    def connect
      @connected = true
    end

    def disconnect
      @connected = false
    end

    def on_error(message)
      @errors << message
    end
  end

  setup do
    @server = TestServer.new
    @server.config.allowed_request_origins = %w( http://rubyonrails.com )
  end

  test "delegate socket errors to on_error handler" do
    run_in_eventmachine do
      connection = open_connection

      # Internal hax = :(
      client = connection.websocket.send(:websocket)
      client.instance_variable_get("@stream").stub(:write, proc { raise "foo" }) do
        assert_not_called(client, :client_gone) do
          client.write("boo")
        end
      end
      assert_equal %w[ foo ], connection.errors
    end
  end

  test "closes hijacked i/o socket at shutdown" do
    run_in_eventmachine do
      connection = open_connection

      client = connection.websocket.send(:websocket)
      event = Concurrent::Event.new
      client.instance_variable_get("@stream")
        .instance_variable_get("@rack_hijack_io")
        .define_singleton_method(:close) { event.set }
      connection.close
      event.wait
    end
  end

  test "a forced close finishes a pending graceful close without waiting for the peer" do
    run_in_eventmachine do
      # Use an RFC 6455 handshake: unlike the Draft75 fallback, its close waits for the peer's close frame
      connection = open_connection("HTTP_SEC_WEBSOCKET_VERSION" => "13", "HTTP_SEC_WEBSOCKET_KEY" => "dGhlIHNhbXBsZSBub25jZQ==")

      connection.close
      wait_for_async
      assert connection.connected, "graceful close must wait for the peer"

      connection.close!
      wait_for_async
      assert_not connection.connected
    end
  end

  private
    def open_connection(headers = {})
      env = Rack::MockRequest.env_for "/test",
        "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com", **headers
      io, client_io = \
        begin
          Socket.pair(Socket::AF_UNIX, Socket::SOCK_STREAM, 0)
        rescue
          StringIO.new
        end
      env["rack.hijack"] = -> { env["rack.hijack_io"] = io }

      TestSocket.new(@server, env).tap do |socket|
        socket.process
        if client_io
          # Make sure server returns handshake response
          Timeout.timeout(1) do
            loop do
              break if client_io.readline == "\r\n"
            end
          end
        end
        socket.send :handle_open
        assert socket.connected
      end
    end
end
