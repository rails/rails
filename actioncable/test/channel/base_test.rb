# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "stubs/test_connection"
require "stubs/room"

class ActionCable::Channel::BaseTest < ActiveSupport::TestCase
  class ActionCable::Channel::Base
    def kick
      @last_action = [ :kick ]
    end

    def topic
    end
  end

  class BasicChannel < ActionCable::Channel::Base
    def chatters
      @last_action = [ :chatters ]
    end
  end

  class ChatChannel < BasicChannel
    attr_reader :room, :last_action
    after_subscribe :toggle_subscribed
    after_unsubscribe :toggle_subscribed

    def initialize(*)
      @subscribed = false
      super
    end

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

    def topic(data)
      @last_action = [ :topic, data ]
    end

    def subscribed?
      @subscribed
    end

    def get_latest
      transmit data: "latest"
    end

    def receive
      @last_action = [ :receive ]
    end

    private
      def rm_rf
        @last_action = [ :rm_rf ]
      end
  end

  setup do
    @user = User.new "lifo"
    @connection = TestConnection.new(@user)
    @channel = ChatChannel.new @connection, "{id: 1}", id: 1
  end

  test "should subscribe to a channel" do
    @channel.subscribe_to_channel
    assert_equal 1, @channel.room.id
  end

  test "on subscribe callbacks" do
    @channel.subscribe_to_channel
    assert @channel.subscribed
  end

  test "channel params" do
    assert_equal({ id: 1 }, @channel.params)
  end

  test "unsubscribing from a channel" do
    @channel.subscribe_to_channel

    assert @channel.room
    assert_predicate @channel, :subscribed?

    @channel.unsubscribe_from_channel

    assert_not @channel.room
    assert_not_predicate @channel, :subscribed?
  end

  test "connection identifiers" do
    assert_equal @user.name, @channel.current_user.name
  end

  test "callable action without any argument" do
    @channel.perform_action "action" => :leave
    assert_equal [ :leave ], @channel.last_action
  end

  test "callable action with arguments" do
    data = { "action" => :speak, "content" => "Hello World" }

    @channel.perform_action data
    assert_equal [ :speak, data ], @channel.last_action
  end

  test "should not dispatch a private method" do
    @channel.perform_action "action" => :rm_rf
    assert_nil @channel.last_action
  end

  test "should not dispatch a public method defined on Base" do
    @channel.perform_action "action" => :kick
    assert_nil @channel.last_action
  end

  test "should dispatch a public method defined on Base and redefined on channel" do
    data = { "action" => :topic, "content" => "This is Sparta!" }

    @channel.perform_action data
    assert_equal [ :topic, data ], @channel.last_action
  end

  test "should dispatch calling a public method defined in an ancestor" do
    @channel.perform_action "action" => :chatters
    assert_equal [ :chatters ], @channel.last_action
  end

  test "should dispatch receive action when perform_action is called with empty action" do
    data = { "content" => "hello" }
    @channel.perform_action data
    assert_equal [ :receive ], @channel.last_action
  end

  test "transmitting data" do
    @channel.perform_action "action" => :get_latest

    expected = { "identifier" => "{id: 1}", "message" => { "data" => "latest" } }
    assert_equal expected, @connection.last_transmission
  end

  test "do not send subscription confirmation on initialize" do
    assert_nil @connection.last_transmission
  end

  test "subscription confirmation on subscribe_to_channel" do
    expected = { "identifier" => "{id: 1}", "type" => "confirm_subscription" }
    @channel.subscribe_to_channel
    assert_equal expected, @connection.last_transmission
  end

  test "actions available on Channel" do
    available_actions = %w(room last_action subscribed unsubscribed toggle_subscribed leave speak subscribed? get_latest receive chatters topic).to_set
    assert_equal available_actions, ChatChannel.action_methods
  end

  test "invalid action on Channel" do
    assert_logged("Unable to process ActionCable::Channel::BaseTest::ChatChannel#invalid_action") do
      @channel.perform_action "action" => :invalid_action
    end
  end

  test "notification for perform_action" do
    begin
      events = []
      ActiveSupport::Notifications.subscribe "perform_action.action_cable" do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      data = { "action" => :speak, "content" => "hello" }
      @channel.perform_action data

      assert_equal 1, events.length
      assert_equal "perform_action.action_cable", events[0].name
      assert_equal "ActionCable::Channel::BaseTest::ChatChannel", events[0].payload[:channel_class]
      assert_equal :speak, events[0].payload[:action]
      assert_equal data, events[0].payload[:data]
    ensure
      ActiveSupport::Notifications.unsubscribe "perform_action.action_cable"
    end
  end

  test "notification for transmit" do
    begin
      events = []
      ActiveSupport::Notifications.subscribe "transmit.action_cable" do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      @channel.perform_action "action" => :get_latest
      expected_data = { data: "latest" }

      assert_equal 1, events.length
      assert_equal "transmit.action_cable", events[0].name
      assert_equal "ActionCable::Channel::BaseTest::ChatChannel", events[0].payload[:channel_class]
      assert_equal expected_data, events[0].payload[:data]
      assert_nil events[0].payload[:via]
    ensure
      ActiveSupport::Notifications.unsubscribe "transmit.action_cable"
    end
  end

  test "notification for transmit_subscription_confirmation" do
    begin
      @channel.subscribe_to_channel

      events = []
      ActiveSupport::Notifications.subscribe "transmit_subscription_confirmation.action_cable" do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      @channel.stub(:subscription_confirmation_sent?, false) do
        @channel.send(:transmit_subscription_confirmation)

        assert_equal 1, events.length
        assert_equal "transmit_subscription_confirmation.action_cable", events[0].name
        assert_equal "ActionCable::Channel::BaseTest::ChatChannel", events[0].payload[:channel_class]
      end
    ensure
      ActiveSupport::Notifications.unsubscribe "transmit_subscription_confirmation.action_cable"
    end
  end

  test "notification for transmit_subscription_rejection" do
    begin
      events = []
      ActiveSupport::Notifications.subscribe "transmit_subscription_rejection.action_cable" do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      @channel.send(:transmit_subscription_rejection)

      assert_equal 1, events.length
      assert_equal "transmit_subscription_rejection.action_cable", events[0].name
      assert_equal "ActionCable::Channel::BaseTest::ChatChannel", events[0].payload[:channel_class]
    ensure
      ActiveSupport::Notifications.unsubscribe "transmit_subscription_rejection.action_cable"
    end
  end

  private
    def assert_logged(message)
      old_logger = @connection.logger
      log = StringIO.new
      @connection.instance_variable_set(:@logger, Logger.new(log))

      begin
        yield

        log.rewind
        assert_match message, log.read
      ensure
        @connection.instance_variable_set(:@logger, old_logger)
      end
    end
end
