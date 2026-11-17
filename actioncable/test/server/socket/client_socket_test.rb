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

    attr_reader :connected, :websocket, :errors, :messages, :close_code

    def initialize(*)
      super
      @errors = []
      @messages = []
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

    def on_message(message)
      @messages << message
    end

    def on_close(reason, code)
      @close_code = code
      super
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

  test "closes the connection with 1009 when a message is larger than max_message_size" do
    @server.config.max_message_size = 16

    run_in_eventmachine do
      connection = open_connection(rfc6455_handshake)
      skip "needs a socket pair" unless @client_io

      @client_io.write(masked_text_frame("x" * 17))

      wait_for { connection.close_code }
      assert_equal 1009, connection.close_code
      assert_equal ["WebSocket frame length too large"], connection.errors
      assert_empty connection.messages
    end
  end

  test "keeps the driver's own size limit when max_message_size is not set" do
    run_in_eventmachine do
      connection = open_connection(rfc6455_handshake)
      skip "needs a socket pair" unless @client_io

      @client_io.write(masked_text_frame("x" * 17))

      wait_for { connection.messages.any? }
      assert_equal ["x" * 17], connection.messages
      assert_nil connection.close_code
      assert connection.websocket.alive?
    end
  end

  private
    def open_connection(headers = {})
      env = Rack::MockRequest.env_for "/test", {
        "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"
      }.merge(headers)
      io, @client_io = \
        begin
          Socket.pair(Socket::AF_UNIX, Socket::SOCK_STREAM, 0)
        rescue
          StringIO.new
        end
      env["rack.hijack"] = -> { env["rack.hijack_io"] = io }

      TestSocket.new(@server, env).tap do |socket|
        socket.process
        if @client_io
          # Make sure server returns handshake response
          Timeout.timeout(1) do
            loop do
              break if @client_io.readline == "\r\n"
            end
          end
        end
        socket.send :handle_open
        assert socket.connected
      end
    end

    # Without these headers websocket-driver speaks draft-75, which has no
    # close codes.
    def rfc6455_handshake
      { "HTTP_SEC_WEBSOCKET_VERSION" => "13", "HTTP_SEC_WEBSOCKET_KEY" => SecureRandom.base64(16) }
    end

    # A client's text frame, masked as RFC 6455 requires, for a payload under 126 bytes.
    def masked_text_frame(text)
      mask = SecureRandom.random_bytes(4)
      payload = text.bytes.each_with_index.map { |byte, i| byte ^ mask.getbyte(i % 4) }.pack("C*")
      [0x81, 0x80 | text.bytesize].pack("CC") + mask + payload
    end
end
