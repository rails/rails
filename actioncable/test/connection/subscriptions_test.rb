# frozen_string_literal: true

require "test_helper"

class ActionCable::Connection::SubscriptionsTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    attr_reader :websocket

    def send_async(method, *args)
      send method, *args
    end
  end

  class ChatChannel < ActionCable::Channel::Base
    attr_reader :room, :lines

    def subscribed
      @room = Room.new params[:id]
      @lines = []
    end

    def speak(data)
      @lines << data
    end
  end

  setup do
    @server = TestServer.new

    @chat_identifier = ActiveSupport::JSON.encode(id: 1, channel: "ActionCable::Connection::SubscriptionsTest::ChatChannel")
  end

  test "subscribe command" do
    run_in_eventmachine do
      setup_connection
      channel = subscribe_to_chat_channel

      assert_kind_of ChatChannel, channel
      assert_equal 1, channel.room.id
    end
  end

  test "subscribe command without an identifier" do
    run_in_eventmachine do
      setup_connection

      @subscriptions.execute_command "command" => "subscribe"
      assert_predicate @subscriptions.identifiers, :empty?
    end
  end

  test "unsubscribe command" do
    run_in_eventmachine do
      setup_connection
      subscribe_to_chat_channel

      channel = subscribe_to_chat_channel
      channel.expects(:unsubscribe_from_channel)

      @subscriptions.execute_command "command" => "unsubscribe", "identifier" => @chat_identifier
      assert_predicate @subscriptions.identifiers, :empty?
    end
  end

  test "unsubscribe command without an identifier" do
    run_in_eventmachine do
      setup_connection

      @subscriptions.execute_command "command" => "unsubscribe"
      assert_predicate @subscriptions.identifiers, :empty?
    end
  end

  test "message command" do
    run_in_eventmachine do
      setup_connection
      channel = subscribe_to_chat_channel

      data = { "content" => "Hello World!", "action" => "speak" }
      @subscriptions.execute_command "command" => "message", "identifier" => @chat_identifier, "data" => ActiveSupport::JSON.encode(data)

      assert_equal [ data ], channel.lines
    end
  end

  test "unsubscribe from all" do
    run_in_eventmachine do
      setup_connection

      channel1 = subscribe_to_chat_channel

      channel2_id = ActiveSupport::JSON.encode(id: 2, channel: "ActionCable::Connection::SubscriptionsTest::ChatChannel")
      channel2 = subscribe_to_chat_channel(channel2_id)

      channel1.expects(:unsubscribe_from_channel)
      channel2.expects(:unsubscribe_from_channel)

      @subscriptions.unsubscribe_from_all
    end
  end

  private
    def subscribe_to_chat_channel(identifier = @chat_identifier)
      @subscriptions.execute_command "command" => "subscribe", "identifier" => identifier
      assert_equal identifier, @subscriptions.identifiers.last

      @subscriptions.send :find, "identifier" => identifier
    end

    def setup_connection
      env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket"
      @connection = Connection.new(@server, env)

      @subscriptions = ActionCable::Connection::Subscriptions.new(@connection)
    end
end
