# frozen_string_literal: true

module ActionCable
  module Connection
    # Wrap the real socket to minimize the externally-presented API
    class WebSocket # :nodoc:
      def initialize(env, event_target, event_loop, protocols: ActionCable::INTERNAL[:protocols])
        @websocket = self.class.new_client(env, event_target, event_loop, protocols)
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

      def self.new_client(env, event_target, event_loop, protocols)
        ClientRackSocket.accept(env, event_target, event_loop, protocols) || ClientFayeSocket.accept(env, event_target, event_loop, protocols)
      end

      private
        attr_reader :websocket
    end
  end
end
