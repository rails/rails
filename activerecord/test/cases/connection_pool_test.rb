require "cases/helper"

class ConnectionManagementTest < ActiveRecord::TestCase
  def setup
    @env = {}
    @app = stub('App')
    @management = ActiveRecord::ConnectionAdapters::ConnectionManagement.new(@app)
    
    @connections_cleared = false
    ActiveRecord::Base.stubs(:clear_active_connections!).with { @connections_cleared = true }
  end
  
  test "clears active connections after each call" do
    @app.expects(:call).with(@env)
    @management.call(@env)
    assert @connections_cleared
  end
  
  test "doesn't clear active connections when running in a test case" do
    @env['rack.test'] = true
    @app.expects(:call).with(@env)
    @management.call(@env)
    assert !@connections_cleared
  end
end