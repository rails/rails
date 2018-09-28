# frozen_string_literal: true

require "websocket/driver"

module ActionCable
  module Connection
    # Wrap the real socket to minimize the externally-presented API
    class WebSocket # :nodoc:
      def initialize(env, event_target, event_loop, protocols: ActionCable::INTERNAL[:protocols])
        @websocket = self.class.create_driver(env, event_target, event_loop, protocols)
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

      private
        attr_reader :websocket

      @driver_selector = nil
      def self.create_driver(env, event_target, event_loop, protocols)
        case @driver_selector
        when :rack
          puts "Remembered..."
          return WebSocketRack.attempt(env, event_target, event_loop, protocols)
        when :driver
          return ::WebSocket::Driver.websocket?(env) && ClientSocket.new(env, event_target, event_loop, protocols)
        end
        return nil unless ::WebSocket::Driver.websocket?(env)
        puts "Calculating memory..."
        ret = WebSocketRack.attempt(env, event_target, event_loop, protocols)
        if (ret)
          @driver_selector = :rack
          return ret
        end
        @driver_selector = :driver 
        return ClientSocket.new(env, event_target, event_loop, protocols)
      end

    end
  end
end
