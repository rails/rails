# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"
require "stubs/user"

class ActionCable::Connection::MultipleIdentifiersTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
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

  private
    def open_connection_with_stubbed_pubsub
      server = TestServer.new
      server.stubs(:pubsub).returns(stub_everything("pubsub"))

      open_connection server: server
    end

    def open_connection(server:)
      env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket"
      @connection = Connection.new(server, env)

      @connection.process
      @connection.send :handle_open
    end
end
