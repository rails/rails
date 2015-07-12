require 'test_helper'
require 'stubs/test_server'

class ActionCable::Connection::AuthorizationTest < ActiveSupport::TestCase
  class Connection < ActionCable::Connection::Base
    attr_reader :websocket

    def connect
      reject_unauthorized_connection
    end
  end

  setup do
    @server = TestServer.new

    env = Rack::MockRequest.env_for "/test", 'HTTP_CONNECTION' => 'upgrade', 'HTTP_UPGRADE' => 'websocket'
    @connection = Connection.new(@server, env)
  end

  test "unauthorized connection" do
    @connection.websocket.expects(:close)

    @connection.process
    @connection.send :on_open
  end
end
