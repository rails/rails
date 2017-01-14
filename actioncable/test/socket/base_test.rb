require "test_helper"
require "stubs/test_server"
require "active_support/core_ext/object/json"

class ActionCable::Socket::BaseTest < ActionCable::TestCase
  class Socket < ActionCable::Socket::Base
    attr_reader :websocket, :message_buffer

    delegate :connected, to: :connection

    def send_async(method, *args)
      send method, *args
    end
  end

  setup do
    @server = TestServer.new
    @server.config.allowed_request_origins = %w( http://rubyonrails.com )
  end

  test "making a socket with invalid headers" do
    run_in_eventmachine do
      socket = ActionCable::Socket::Base.new(@server, Rack::MockRequest.env_for("/test"))
      response = socket.process
      assert_equal 404, response[0]
    end
  end

  test "websocket socket" do
    run_in_eventmachine do
      socket = open_socket
      socket.process

      assert socket.websocket.possible?

      wait_for_async
      assert socket.websocket.alive?
    end
  end

  test "rack response" do
    run_in_eventmachine do
      socket = open_socket
      response = socket.process

      assert_equal [ -1, {}, [] ], response
    end
  end

  test "on socket open" do
    run_in_eventmachine do
      socket = open_socket

      socket.websocket.expects(:transmit).with({ type: "welcome" }.to_json)
      socket.message_buffer.expects(:process!)

      socket.process
      wait_for_async

      assert_equal [ socket.connection ], @server.connections
      assert socket.connected
    end
  end

  test "on socket close" do
    run_in_eventmachine do
      socket = open_socket
      socket.process

      # Setup the socket
      socket.server.stubs(:timer).returns(true)
      socket.send :handle_open
      assert socket.connected

      socket.send :handle_close
      assert ! socket.connected
      assert_equal [], @server.connections
    end
  end

  test "socket statistics" do
    run_in_eventmachine do
      socket = open_socket
      socket.process

      statistics = socket.statistics

      assert statistics[:identifier].blank?
      assert_kind_of Time, statistics[:started_at]
      assert_equal [], statistics[:subscriptions]
    end
  end

  test "explicitly closing a socket" do
    run_in_eventmachine do
      socket = open_socket
      socket.process

      socket.websocket.expects(:close)
      socket.close
    end
  end

  test "rejecting a socket causes a 404" do
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

      socket = ActionCable::Socket::Base.new(@server, env)
      response = socket.process
      assert_equal 404, response[0]
    end
  end

  private
    def open_socket
      env = Rack::MockRequest.env_for "/test", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"

      Socket.new(@server, env)
    end
end
