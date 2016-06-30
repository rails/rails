require 'test_helper'
require 'stubs/test_server'

class ActionCable::Connection::ClientSocketTest < ActionCable::TestCase
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

  test 'delegate socket errors to on_error handler' do
    skip if ENV['FAYE'].present?

    run_in_eventmachine do
      connection = open_connection

      # Internal hax = :(
      client = connection.websocket.send(:websocket)
      client.instance_variable_get('@stream').expects(:write).raises('foo')
      client.expects(:client_gone).never

      client.write('boo')
      assert_equal %w[ foo ], connection.errors
    end
  end

  test 'closes hijacked i/o socket at shutdown' do
    skip if ENV['FAYE'].present?

    run_in_eventmachine do
      connection = open_connection

      client = connection.websocket.send(:websocket)
      client.instance_variable_get('@stream')
        .instance_variable_get('@rack_hijack_io')
        .expects(:close)
      connection.close
    end
  end

  private
    def open_connection
      env = Rack::MockRequest.env_for '/test',
        'HTTP_CONNECTION' => 'upgrade', 'HTTP_UPGRADE' => 'websocket',
        'HTTP_HOST' => 'localhost', 'HTTP_ORIGIN' => 'http://rubyonrails.com'
      env['rack.hijack'] = -> { env['rack.hijack_io'] = StringIO.new }

      Connection.new(@server, env).tap do |connection|
        connection.process
        connection.send :handle_open
        assert connection.connected
      end
    end
end
