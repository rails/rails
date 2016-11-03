require "test_helper"

class ActionCable::Channel::NamingTest < ActiveSupport::TestCase
  class ChatChannel < ActionCable::Channel::Base
  end

  test "channel_name" do
    assert_equal "action_cable:channel:naming_test:chat", ChatChannel.channel_name
  end
end
