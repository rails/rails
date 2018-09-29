# frozen_string_literal: true

require "websocket/driver"

module ActionCable
  module Connection
    # Wrap the real socket to minimize the externally-presented API
    class WebSocket # :nodoc:
      def initialize(env, event_target, event_loop, protocols: ActionCable::INTERNAL[:protocols])
        @websocket = self.class.establish_connection(env, event_target, event_loop, protocols)
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

      def self.establish_connection(env, event_target, event_loop, protocols)
        case driver_selector
        when :rack
          return RackClientSocket.attempt(env, event_target, event_loop, protocols)
        when :driver
          return ::WebSocket::Driver.websocket?(env) && ClientSocket.new(env, event_target, event_loop, protocols)
        end
        record_drive_selector(env) && establish_connection(env, event_target, event_loop, protocols)
      end

      private

        attr_reader :websocket
        attr_accessor :driver_selector
        def self.record_drive_selector(env)
          return (driver_selector = :rack) if (RackClientSocket.websocket?(env))
          return (driver_selector = :driver) if ::WebSocket::Driver.websocket?(env)
          nil
        end

    end
  end
end
