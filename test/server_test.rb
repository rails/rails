require 'test_helper'

# FIXME: Currently busted.
#
# class ServerTest < ActionCableTest
#   class ChatChannel < ActionCable::Channel::Base
#   end
# 
#   class ChatServer < ActionCable::Server::Base
#     register_channels ChatChannel
#   end
# 
#   def app
#     ChatServer
#   end
# 
#   test "channel registration" do
#     assert_equal ChatServer.channel_classes, Set.new([ ChatChannel ])
#   end
# 
#   test "subscribing to a channel with valid params" do
#     ws = Faye::WebSocket::Client.new(websocket_url)
# 
#     ws.on(:message) do |message|
#       puts message.inspect
#     end
# 
#     ws.send command: 'subscribe', identifier: { channel: 'chat'}.to_json
#   end
# 
#   test "subscribing to a channel with invalid params" do
#   end
# end
