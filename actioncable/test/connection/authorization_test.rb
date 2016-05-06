require 'test_helper'

class ActionCable::Connection::AuthorizationTest < ActionCable::TestCase
  class Connection < TestConnection
    def connect
      reject_unauthorized_connection
    end
  end

  test "unauthorized connection" do
    run_in_eventmachine do
      server = TestServer.new
      server.config.allowed_request_origins = %w( http://rubyonrails.com )

      connection = Connection.new(server, default_env)
      connection.websocket.expects(:close)

      connection.process
    end
  end
end
