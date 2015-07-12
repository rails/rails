require 'test_helper'
require 'stubs/test_server'

class ActionCable::Connection::BaseTest < ActiveSupport::TestCase
  setup do
    @server = TestServer.new

    env = Rack::MockRequest.env_for "/test", 'HTTP_CONNECTION' => 'upgrade', 'HTTP_UPGRADE' => 'websocket'
    @connection = ActionCable::Connection::Base.new(@server, env)
  end

  test "making a connection with invalid headers" do
    connection = ActionCable::Connection::Base.new(@server, Rack::MockRequest.env_for("/test"))
    response = connection.process
    assert_equal 404, response[0]
  end
end
