require 'test_helper'

class ServerTest < ActionCableTest

  class ChatChannel < ActionCable::Channel::Base
    def self.matches?(identifier)
      identifier[:channel] == 'chat' && identifier[:user_id].to_i.nonzero?
    end
  end

  class ChatServer < ActionCable::Server
    register_channels ChatChannel
  end

  def app
    ChatServer
  end

  test "channel registration" do
    assert_equal ChatServer.registered_channels, Set.new([ ChatChannel ])
  end

  test "subscribing to a channel with valid params" do
    ws = Faye::WebSocket::Client.new(websocket_url)

    ws.on(:message) do |message|
      puts message.inspect
    end

    ws.send action: 'subscribe', identifier: { channel: 'chat'}.to_json
  end

  test "subscribing to a channel with invalid params" do
  end

end
