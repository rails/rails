require 'test_helper'

class ActionCable::Connection::StreamTest < ActionCable::TestCase
  setup do
    @server = TestServer.new
    @server.config.allowed_request_origins = %w( http://rubyonrails.com )
  end

  [ EOFError, Errno::ECONNRESET ].each do |closed_exception|
    test "closes socket on #{closed_exception}" do
      skip if ENV['FAYE'].present?

      run_in_eventmachine do
        connection = open_connection

        # Internal hax = :(
        client = connection.websocket.send(:websocket)
        client.instance_variable_get('@stream').instance_variable_get('@rack_hijack_io').expects(:write).raises(closed_exception, 'foo')
        client.expects(:client_gone)

        client.write('boo')
        assert_equal [], connection.errors
      end
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
