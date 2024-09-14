# frozen_string_literal: true

# :markup: markdown

require "websocket/driver"

module ActionCable
  module Connection
    # # Action Cable Connection WebSocket
    #
    # Wrap the real socket to minimize the externally-presented API
    class WebSocket # :nodoc:
      def initialize(env, event_target, event_loop, protocols: ActionCable::INTERNAL[:protocols])
        @websocket = ::WebSocket::Driver.websocket?(env) ? ClientSocket.new(env, event_target, event_loop, protocols) : nil
      end

      def possible?
        websocket
      end

      def alive?
        websocket&.alive?
      end

      def transmit(...)
        websocket&.transmit(...)
      end

      def close(...)
        websocket&.close(...)
      end

      def protocol
        websocket&.protocol
      end

      def rack_response
        websocket&.rack_response
      end

      private
        attr_reader :websocket
    end
  end
end
