require 'test_helper'

class ActionCable::Connection::ClientSocketTest < ActionCable::TestCase
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

  private
    def open_connection
      TestConnection.new(@server, rack_hijack_env).tap do |connection|
        connection.process
        connection.send :handle_open
        assert connection.connected
      end
    end
end
