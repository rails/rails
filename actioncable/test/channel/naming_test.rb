require 'test_helper'

class ActionCable::Channel::NamingTest < ActiveSupport::TestCase
  class ChatChannel < ActionCable::Channel::Base
  end

  test "normal channel_name" do
    assert_equal "test", TestChannel.channel_name
  end

  test "nested channel_name" do
    assert_equal "action_cable:channel:naming_test:chat", ChatChannel.channel_name
  end
end
