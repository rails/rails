# frozen_string_literal: true

require "test_helper"

class ActionCable::Connection::SubscriptionsTest < ActionCable::TestCase
  class ChatChannelError < Exception; end

  class Connection < ActionCable::Connection::Base
    attr_reader :exceptions

    rescue_from ChatChannelError, with: :error_handler

    def initialize(*)
      super
      @exceptions = []
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

  class FailToSubscribeChannel < ActionCable::Channel::Base
    def subscribed
      raise ChatChannelError.new("Uh Oh")
    end
  end

  setup do
    @server = TestServer.new
    @chat_identifier = ActiveSupport::JSON.encode(id: 1, channel: "ActionCable::Connection::SubscriptionsTest::ChatChannel")
  end

  test "subscribe command" do
    setup_connection
    channel = subscribe_to_chat_channel

    assert_kind_of ChatChannel, channel
    assert_equal 1, channel.room.id
  end

  test "subscribe command without an identifier" do
    setup_connection

    assert_raises ActionCable::Connection::Subscriptions::MalformedCommandError do
      @subscriptions.execute_command "command" => "subscribe"
    end

    assert_empty @subscriptions.identifiers
  end

  test "subscribe command with Base channel" do
    setup_connection

    identifier = ActiveSupport::JSON.encode(id: 1, channel: "ActionCable::Channel::Base")

    assert_raises ActionCable::Connection::Subscriptions::ChannelNotFound do
      @subscriptions.execute_command "command" => "subscribe", "identifier" => identifier
    end

    assert_empty @subscriptions.identifiers
  end

  test "subscribe command without a channel" do
    setup_connection

    identifier = ActiveSupport::JSON.encode(id: 1)

    assert_raises ActionCable::Connection::Subscriptions::ChannelNotFound do
      @subscriptions.execute_command "command" => "subscribe", "identifier" => identifier
    end

    assert_empty @subscriptions.identifiers
  end

  test "double subscribe command" do
    setup_connection

    subscribe_to_chat_channel

    assert_raises ActionCable::Connection::Subscriptions::AlreadySubscribedError do
      subscribe_to_chat_channel
    end

    assert_equal 1, @subscriptions.identifiers.size
  end

  test "subscribe command does not leave a slot when subscribe_to_channel raises" do
    setup_connection

    identifier = ActiveSupport::JSON.encode(id: 1, channel: "ActionCable::Connection::SubscriptionsTest::FailToSubscribeChannel")
    subscribe = -> { @subscriptions.execute_command "command" => "subscribe", "identifier" => identifier }

    # `add` inserts the slot, then `subscribe_to_channel` runs `subscribed`,
    # which raises. The half-initialized subscription must not be left behind...
    assert_raises(ChatChannelError) { subscribe.call }
    assert_empty @subscriptions.identifiers

    # ...otherwise the slot stays "poisoned": the same identifier could never be
    # subscribed again, every retry being rejected with AlreadySubscribedError.
    # Here the retry instead reaches the channel again (raising ChatChannelError),
    # proving the slot was freed.
    assert_raises(ChatChannelError) { subscribe.call }
  end

  test "unsubscribe command" do
    setup_connection

    channel = subscribe_to_chat_channel

    assert_called(channel, :unsubscribe_from_channel) do
      @subscriptions.execute_command "command" => "unsubscribe", "identifier" => @chat_identifier
    end

    assert_empty @subscriptions.identifiers
  end

  test "unsubscribe command without an identifier" do
    setup_connection

    assert_raises ActionCable::Connection::Subscriptions::MissingIdentifier do
      @subscriptions.execute_command "command" => "unsubscribe"
    end

    assert_empty @subscriptions.identifiers
  end

  test "unsubscribe from non-existent subscription" do
    run_in_eventmachine do
      setup_connection

      assert_nothing_raised do
        @subscriptions.remove("identifier" => @chat_identifier)
      end
      assert_empty @subscriptions.identifiers
    end
  end

  test "perform action on non-existent subscription" do
    run_in_eventmachine do
      setup_connection

      data = { "content" => "Hello World!", "action" => "speak" }

      error = assert_raises ActionCable::Connection::Subscriptions::UnknownSubscription do
        @subscriptions.perform_action("identifier" => @chat_identifier, "data" => ActiveSupport::JSON.encode(data))
      end
      assert_match(/Unable to find subscription/, error.message)
    end
  end

  test "message command" do
    setup_connection
    channel = subscribe_to_chat_channel

    data = { "content" => "Hello World!", "action" => "speak" }
    @subscriptions.execute_command "command" => "message", "identifier" => @chat_identifier, "data" => ActiveSupport::JSON.encode(data)

    assert_equal [ data ], channel.lines
  end

  test "accessing exceptions thrown during command execution" do
    setup_connection
    subscribe_to_chat_channel

    data = { "content" => "Hello World!", "action" => "throw_exception" }
    @connection.handle_channel_command({ "command" => "message", "identifier" => @chat_identifier, "data" => ActiveSupport::JSON.encode(data) })

    exception = @connection.exceptions.first
    assert_kind_of ChatChannelError, exception
  end

  test "unsubscribe from all" do
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

  private
    def subscribe_to_chat_channel(identifier = @chat_identifier)
      @subscriptions.execute_command "command" => "subscribe", "identifier" => identifier
      assert_equal identifier, @subscriptions.identifiers.last

      @subscriptions.send :find, "identifier" => identifier
    end

    def setup_connection
      env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket"
      socket = ActionCable::Server::Socket.new(@server, env)

      @connection = Connection.new(@server, socket)
      @subscriptions = @connection.subscriptions
    end
end
