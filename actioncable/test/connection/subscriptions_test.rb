# frozen_string_literal: true

require "test_helper"

class ActionCable::Connection::SubscriptionsTest < ActionCable::TestCase
  class ChatChannelError < Exception; end

  class Connection < ActionCable::Connection::Base
    attr_reader :websocket, :exceptions

    rescue_from ChatChannelError, with: :error_handler

    def initialize(*)
      super
      @exceptions = []
    end

    def send_async(method, *args)
      send method, *args
    end

    def error_handler(e)
      @exceptions << e
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

    def throw_exception(_data)
      raise ChatChannelError.new("Uh Oh")
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
      assert_empty @subscriptions.identifiers
    end
  end

  test "unsubscribe command" do
    run_in_eventmachine do
      setup_connection
      subscribe_to_chat_channel

      channel = subscribe_to_chat_channel

      assert_called(channel, :unsubscribe_from_channel) do
        @subscriptions.execute_command "command" => "unsubscribe", "identifier" => @chat_identifier
      end

      assert_empty @subscriptions.identifiers
    end
  end

  test "unsubscribe command without an identifier" do
    run_in_eventmachine do
      setup_connection

      @subscriptions.execute_command "command" => "unsubscribe"
      assert_empty @subscriptions.identifiers
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

  test "accessing exceptions thrown during command execution" do
    run_in_eventmachine do
      setup_connection
      subscribe_to_chat_channel

      data = { "content" => "Hello World!", "action" => "throw_exception" }
      @subscriptions.execute_command "command" => "message", "identifier" => @chat_identifier, "data" => ActiveSupport::JSON.encode(data)

      exception = @connection.exceptions.first
      assert_kind_of ChatChannelError, exception
    end
  end

  test "unsubscribe from all" do
    run_in_eventmachine do
      setup_connection

      channel1 = subscribe_to_chat_channel

      channel2_id = ActiveSupport::JSON.encode(id: 2, channel: "ActionCable::Connection::SubscriptionsTest::ChatChannel")
      channel2 = subscribe_to_chat_channel(channel2_id)

      assert_called(channel1, :unsubscribe_from_channel) do
        assert_called(channel2, :unsubscribe_from_channel) do
          @subscriptions.unsubscribe_from_all
        end
      end
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
