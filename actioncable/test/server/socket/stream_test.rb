# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "stubs/test_server"

class ActionCable::Server::Socket::StreamTest < ActionCable::TestCase
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

  [ EOFError, Errno::ECONNRESET ].each do |closed_exception|
    test "closes socket on #{closed_exception}" do
      run_in_eventmachine do
        rack_hijack_io = File.open(File::NULL, "w")
        connection = open_connection(rack_hijack_io)

        # Internal hax = :(
        client = connection.websocket.send(:websocket)
        rack_hijack_io.stub(:write_nonblock, proc { raise(closed_exception, "foo") }) do
          assert_called(client, :client_gone) do
            client.write("boo")
          end
        end
        assert_equal [], connection.errors
      end
    end
  end

  private
    def open_connection(io)
      env = Rack::MockRequest.env_for "/test",
        "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"
      env["rack.hijack"] = -> { env["rack.hijack_io"] = io }

      TestSocket.new(@server, env).tap do |socket|
        socket.process
        socket.send :handle_open
        assert socket.connected
      end
    end
end
