require 'test_helper'

# FIXME: Currently busted.
#
# class ChannelTest < ActionCableTest
#   class PingChannel < ActionCable::Channel::Base
#   end
# 
#   class PingServer < ActionCable::Server::Base
#     register_channels PingChannel
#   end
# 
#   def app
#     PingServer
#   end
# 
#   test "channel callbacks" do
#     ws = Faye::WebSocket::Client.new(websocket_url)
#   end
# end 