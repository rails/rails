require 'test_helper'
require 'stubs/test_connection'
require 'active_support/log_subscriber/test_helper'
require 'action_cable/channel/log_subscriber'

class ActionCable::Channel::LogSubscriberTest < ActiveSupport::TestCase
  include ActiveSupport::LogSubscriber::TestHelper

  class ChatChannel < ActionCable::Channel::Base
    attr_reader :last_action

    def speak(data)
      @last_action = [ :speak, data ]
    end

    def get_latest
      transmit data: 'latest'
    end
  end

  def setup
    super
    @connection = TestConnection.new
    @channel = ChatChannel.new @connection, "{id: 1}", { id: 1 }
    ActionCable::Channel::LogSubscriber.attach_to :action_cable
  end

  def test_perform_action
    data = {'action' => :speak, 'content' => 'hello'}
    @channel.perform_action(data)
    wait

    assert_equal(1, logs.size)
    assert_match(/Completed #{channel_class}#speak in \d+ms/, logs.first)
  end

  def test_transmit
    @channel.perform_action('action' => :get_latest)
    wait

    assert_equal(2, logs.size)
    assert_match(/^#{channel_class} transmitting/, logs.first)
  end

  def test_transmit_subscription_confirmation
    @channel.stubs(:subscription_confirmation_sent?).returns(false)
    @channel.send(:transmit_subscription_confirmation)
    wait

    assert_equal(1, logs.size)
    assert_equal("#{channel_class} is transmitting the subscription confirmation", logs.first)
  end

  def test_transmit_subscription_rejection
    @channel.send(:transmit_subscription_rejection)
    wait

    assert_equal(1, logs.size)
    assert_equal("#{channel_class} is transmitting the subscription rejection", logs.first)
  end

  def channel_class
    "ActionCable::Channel::LogSubscriberTest::ChatChannel"
  end

  def logs
    @logs ||= @logger.logged(:info)
  end
end
