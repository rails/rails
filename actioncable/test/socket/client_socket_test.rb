require "test_helper"
require "stubs/test_server"

class ActionCable::Socket::ClientSocketTest < ActionCable::TestCase
  class Socket < ActionCable::Socket::Base
    attr_reader :websocket, :errors

    delegate :connected, to: :connection

    def initialize(*)
      super
      @errors = []
    end

    def send_async(method, *args)
      send method, *args
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
      socket = open_socket

      # Internal hax = :(
      client = socket.websocket.send(:websocket)
      client.instance_variable_get("@stream").expects(:write).raises("foo")
      client.expects(:client_gone).never

      client.write("boo")
      assert_equal %w[ foo ], socket.errors
    end
  end

  test "closes hijacked i/o socket at shutdown" do
    run_in_eventmachine do
      socket = open_socket

      client = socket.websocket.send(:websocket)
      event = Concurrent::Event.new
      client.instance_variable_get("@stream")
        .instance_variable_get("@rack_hijack_io")
        .define_singleton_method(:close) { event.set }
      socket.close
      event.wait
    end
  end

  private
    def open_socket
      env = Rack::MockRequest.env_for "/test",
        "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"
      io = \
        begin
          ::Socket.pair(::Socket::AF_UNIX, ::Socket::SOCK_STREAM, 0).first
        rescue
          StringIO.new
        end
      env["rack.hijack"] = -> { env["rack.hijack_io"] = io }

      Socket.new(@server, env).tap do |socket|
        socket.process
        socket.send :handle_open
        assert socket.connected
      end
    end
end
