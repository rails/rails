require 'test_helper'

class ActionCable::Connection::MultipleIdentifiersTest < ActionCable::TestCase
  class Connection < TestConnection
    identified_by :current_user, :current_room

    def connect
      self.current_user = User.new "lifo"
      self.current_room = Room.new "my", "room"
    end
  end

  test "multiple connection identifiers" do
    run_in_eventmachine do
      open_connection_with_stubbed_pubsub
      assert_equal "Room#my-room:User#lifo", @connection.connection_identifier
    end
  end

  protected
    def open_connection_with_stubbed_pubsub
      server = TestServer.new
      server.stubs(:pubsub).returns(stub_everything('pubsub'))

      open_connection server: server
    end

    def open_connection(server:)
      @connection = Connection.new(server, default_env)

      @connection.process
      @connection.send :handle_open
    end

    def close_connection
      @connection.send :handle_close
    end
end
