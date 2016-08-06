require 'test_helper'
require 'stubs/test_server'

class ActionCable::RemoteConnections::BaseTest < ActionCable::TestCase
  test '#where' do
    server             = TestServer.new
    remote_connections = ActionCable::RemoteConnections.new(server)
    remote_connection  = remote_connections.where(var1: 1, var2: 2, var3: 3)
    assert_instance_of ActionCable::RemoteConnections::RemoteConnection, remote_connection
    assert_equal 1, remote_connection.instance_variable_get(:@var1)
    assert_equal 2, remote_connection.instance_variable_get(:@var2)
    assert_equal 3, remote_connection.instance_variable_get(:@var3)
  end
end
