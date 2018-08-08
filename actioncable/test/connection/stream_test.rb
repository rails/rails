# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "stubs/test_server"

class ActionCable::Connection::StreamTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    attr_reader :connected, :websocket, :errors

    def initialize(*)
      super
      @errors = []
    end

    def connect
      @connected = true
    end

    def disconnect
      @connected = false
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
        connection = open_connection

        # Internal hax = :(
        client = connection.websocket.send(:websocket)
        rack_hijack_io = client.instance_variable_get("@stream").instance_variable_get("@rack_hijack_io")
        rack_hijack_io.stub(:write, proc { raise(closed_exception, "foo") }) do
          assert_called(client, :client_gone) do
            client.write("boo")
          end
        end
        assert_equal [], connection.errors
      end
    end
  end

  private
    def open_connection
      env = Rack::MockRequest.env_for "/test",
        "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"
      env["rack.hijack"] = -> { env["rack.hijack_io"] = StringIO.new }

      Connection.new(@server, env).tap do |connection|
        connection.process
        connection.send :handle_open
        assert connection.connected
      end
    end
end
