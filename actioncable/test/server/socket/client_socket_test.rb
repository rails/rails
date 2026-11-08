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
      assert event.wait(5), "hijacked i/o socket was not closed"
    end
  end

  test "closes the connection when the event loop can't attach the socket" do
    run_in_eventmachine do
      @server.event_loop.send(:spawn)
      selector = @server.event_loop.instance_variable_get(:@nio)

      handshake_written = Concurrent::Event.new

      selector.stub(:register, proc { handshake_written.wait(5); raise ArgumentError, "mode not supported" }) do
        connection = open_connection
        io = connection.env["rack.hijack_io"]
        handshake_written.set

        wait_for_async
        Timeout.timeout(5) { sleep 0.01 until io.closed? }
        assert_not connection.websocket.alive?
      end
    end
  end

  private
    def open_connection
      env = Rack::MockRequest.env_for "/test",
        "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"
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
