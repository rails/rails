require "test_helper"
require "stubs/test_server"

class ActionCable::Socket::StreamTest < ActionCable::TestCase
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

  [ EOFError, Errno::ECONNRESET ].each do |closed_exception|
    test "closes socket on #{closed_exception}" do
      run_in_eventmachine do
        socket = open_socket

        # Internal hax = :(
        client = socket.websocket.send(:websocket)
        client.instance_variable_get("@stream").instance_variable_get("@rack_hijack_io").expects(:write).raises(closed_exception, "foo")
        client.expects(:client_gone)

        client.write("boo")
        assert_equal [], socket.errors
      end
    end
  end

  private
    def open_socket
      env = Rack::MockRequest.env_for "/test",
        "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"
      env["rack.hijack"] = -> { env["rack.hijack_io"] = StringIO.new }

      Socket.new(@server, env).tap do |socket|
        socket.process
        socket.send :handle_open
        assert socket.connected
      end
    end
end
