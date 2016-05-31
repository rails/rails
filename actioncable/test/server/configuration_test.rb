require "test_helper"

class BroadcastingTest < ActiveSupport::TestCase
  class TestServer
    include ActionCable::Server::Broadcasting
  end

  test "properly formats channel_class_names" do
    config = ActionCable::Server::Configuration.new
    config.channel_paths = [
      "myrootpath/app/channels/room_channel.rb",
      "myrootpath/app/channels/test/room_channel.rb"
    ]

    config.base_channel_path = Pathname.new('myrootpath/app/channels')

    assert_equal ["RoomChannel", "Test::RoomChannel"], config.channel_class_names
  end
end
