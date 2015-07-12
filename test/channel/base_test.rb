require 'test_helper'
require 'stubs/test_connection'

class ActionCable::Channel::BaseTest < ActiveSupport::TestCase
  Room = Struct.new(:id)

  class ChatChannel < ActionCable::Channel::Base
    attr_reader :room, :last_action
    on_subscribe :toggle_subscribed
    on_unsubscribe :toggle_subscribed

    def subscribed
      @room = Room.new params[:id]
      @actions = []
    end

    def unsubscribed
      @room = nil
    end

    def toggle_subscribed
      @subscribed = !@subscribed
    end

    def leave
      @last_action = [ :leave ]
    end

    def speak(data)
      @last_action = [ :speak, data ]
    end

    def subscribed?
      @subscribed
    end

    def get_latest
      transmit data: 'latest'
    end

    private
      def rm_rf
        @last_action = [ :rm_rf ]
      end
  end

  setup do
    @user = User.new "lifo"
    @connection = TestConnection.new(@user)
    @channel = ChatChannel.new @connection, "{id: 1}", { id: 1 }
  end

  test "should subscribe to a channel on initialize" do
    assert_equal 1, @channel.room.id
  end

  test "on subscribe callbacks" do
    assert @channel.subscribed
  end

  test "channel params" do
    assert_equal({ id: 1 }, @channel.params)
  end

  test "unsubscribing from a channel" do
    assert @channel.room
    assert @channel.subscribed?

    @channel.unsubscribe_from_channel

    assert ! @channel.room
    assert ! @channel.subscribed?
  end

  test "connection identifiers" do
    assert_equal @user.name, @channel.current_user.name
  end

  test "callable action without any argument" do
    @channel.perform_action 'action' => :leave
    assert_equal [ :leave ], @channel.last_action
  end

  test "callable action with arguments" do
    data = { 'action' => :speak, 'content' => "Hello World" }

    @channel.perform_action data
    assert_equal [ :speak, data ], @channel.last_action
  end

  test "try calling a private method" do
    @channel.perform_action 'action' => :rm_rf
    assert_nil @channel.last_action
  end

  test "transmitting data" do
    @channel.perform_action 'action' => :get_latest

    expected = ActiveSupport::JSON.encode "identifier" => "{id: 1}", "message" => { "data" => "latest" }
    assert_equal expected, @connection.last_transmission
  end
end
