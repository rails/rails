# frozen_string_literal: true

require "test_helper"

class ActionCable::RemoteConnectionsTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = User.new "lifo"
    end
  end

  setup do
    @server = TestServer.new(connection_class: Connection)
  end

  test "unsubscribe broadcasts correct message to internal channel" do
    run_in_eventmachine do
      events = []
      ActiveSupport::Notifications.subscribe "broadcast.action_cable" do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      setup_connection
      remote_connections = ActionCable::RemoteConnections.new(@server)
      remote_connections.where(current_user: "User#lifo").unsubscribe("subscription_identifier")

      broadcasting = "action_cable/User#lifo"
      message = { :type=>"unsubscribe", :channel_identifier => "subscription_identifier" }
      assert_equal broadcasting, events[0].payload[:broadcasting]
      assert_equal message, events[0].payload[:message]
    end
  ensure
    ActiveSupport::Notifications.unsubscribe "broadcast.action_cable"
  end

  private
    def setup_connection
      env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket"
      @connection = Connection.new(@server, env)

      @subscriptions = ActionCable::Connection::Subscriptions.new(@connection)
    end
end
