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
    open_connection

    assert_equal "Room#my-room:User#lifo", @connection.connection_identifier
  end

  private
    def open_connection
      server = TestServer.new
      env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket"

      @socket = ActionCable::Server::Socket.new(server, env)
      @connection = Connection.new(server, @socket).tap(&:handle_open)
    end
end
