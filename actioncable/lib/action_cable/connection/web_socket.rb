# frozen_string_literal: true

require "websocket/driver"

module ActionCable
  module Connection
    # Wrap the real socket to minimize the externally-presented API
    class WebSocket # :nodoc:
      def initialize(env, event_target, event_loop, protocols: ActionCable::INTERNAL[:protocols])
        @websocket = ::WebSocket::Driver.websocket?(env) ? ClientSocket.new(env, event_target, event_loop, protocols) : nil
      end

      def possible?
        websocket
      end

      def alive?
        websocket && websocket.alive?
      end

      def transmit(data)
        websocket.transmit data
      end

      def close
        websocket.close
      end

      def protocol
        websocket.protocol
      end

      def rack_response
        websocket.rack_response
      end

      # TODO Change this to private once we've dropped Ruby 2.2 support.
      # Workaround for Ruby 2.2 "private attribute?" warning.
      protected
        attr_reader :websocket
    end
  end
end
