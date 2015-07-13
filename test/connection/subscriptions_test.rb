require 'test_helper'

class ActionCable::Connection::SubscriptionsTest < ActiveSupport::TestCase
  class Connection < ActionCable::Connection::Base
    attr_reader :websocket
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
    @server.stubs(:channel_classes).returns([ ChatChannel ])

    env = Rack::MockRequest.env_for "/test", 'HTTP_CONNECTION' => 'upgrade', 'HTTP_UPGRADE' => 'websocket'
    @connection = Connection.new(@server, env)

    @subscriptions = ActionCable::Connection::Subscriptions.new(@connection)
    @chat_identifier = { id: 1, channel: 'ActionCable::Connection::SubscriptionsTest::ChatChannel' }.to_json
  end

  test "subscribe command" do
    channel = subscribe_to_chat_channel

    assert_kind_of ChatChannel, channel
    assert_equal 1, channel.room.id
  end

  test "subscribe command without an identifier" do
    @subscriptions.execute_command 'command' => 'subscribe'
    assert @subscriptions.identifiers.empty?
  end

  test "unsubscribe command" do
    subscribe_to_chat_channel

    channel = subscribe_to_chat_channel
    channel.expects(:unsubscribe_from_channel)

    @subscriptions.execute_command 'command' => 'unsubscribe', 'identifier' => @chat_identifier
    assert @subscriptions.identifiers.empty?
  end

  test "unsubscribe command without an identifier" do
    @subscriptions.execute_command 'command' => 'unsubscribe'
    assert @subscriptions.identifiers.empty?
  end

  test "message command" do
    channel = subscribe_to_chat_channel

    data = { 'content' => 'Hello World!', 'action' => 'speak' }
    @subscriptions.execute_command 'command' => 'message', 'identifier' => @chat_identifier, 'data' => data.to_json

    assert_equal [ data ], channel.lines
  end

  test "unsubscrib from all" do
    channel1 = subscribe_to_chat_channel

    channel2_id = { id: 2, channel: 'ActionCable::Connection::SubscriptionsTest::ChatChannel' }.to_json
    channel2 = subscribe_to_chat_channel(channel2_id)

    channel1.expects(:unsubscribe_from_channel)
    channel2.expects(:unsubscribe_from_channel)

    @subscriptions.unsubscribe_from_all
  end

  private
    def subscribe_to_chat_channel(identifier = @chat_identifier)
      @subscriptions.execute_command 'command' => 'subscribe', 'identifier' => identifier
      assert_equal identifier, @subscriptions.identifiers.last

      @subscriptions.send :find, 'identifier' => identifier
    end
end
