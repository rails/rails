require 'test_helper'

class ChannelTest < ActionCableTest

  class PingChannel < ActionCable::Channel::Base
    def self.matches?(identifier)
      identifier[:channel] == 'chat' && identifier[:user_id].to_i.nonzero?
    end
  end

  class PingServer < ActionCable::Server
    register_channels PingChannel
  end

  def app
    PingServer
  end

  test "channel callbacks" do
    ws = Faye::WebSocket::Client.new(websocket_url)
  end

end
