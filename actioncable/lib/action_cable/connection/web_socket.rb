# frozen_string_literal: true

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

      # by order of preference, the first supported client will be chosen
      CLIENT_SOCKET_CANDIDATES = [ClientRackSocket, ClientFayeSocket]

      def self.establish_connection(env, event_target, event_loop, protocols)
        @client_socket_klass ||= client_socket_selector(env)
        @client_socket_klass&.attempt(env, event_target, event_loop, protocols)
      end

      private
        attr_reader :websocket

        def self.client_socket_selector(env)
          CLIENT_SOCKET_CANDIDATES.each { |klass| return klass if klass.accept?(env) }
          nil
        end
    end
  end
end
