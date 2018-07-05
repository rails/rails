# frozen_string_literal: true

module ActionCable
  module Connection
    # Wrap the real socket to minimize the externally-presented API
    #
    # This variation leverages the `rack.upgrade?` approach detailed here: https://github.com/rack/rack/pull/1272
    class WebSocketRack # :nodoc:
      UPGRADE_EXISTS = "rack.upgrade?".freeze
      UPGRADE = "rack.upgrade".freeze
      PROTOCOL_NAME_IN = "HTTP_SEC_WEBSOCKET_PROTOCOL".freeze
      PROTOCOL_NAME_OUT = "Sec-Websocket-Protocol".freeze
      CLOSE_REASON = "".freeze
      def initialize(env, event_target, event_loop, protocols)
        env[UPGRADE] = self
        @event_target = event_target
        @protocol = nil
        @websocket = nil
        if env[PROTOCOL_NAME_IN]
          if env[PROTOCOL_NAME_IN].is_a?(String)   # for single list headers such as "json, soap, foo"
            env[PROTOCOL_NAME_IN].split(/,[\s]?/).each { |i| next unless protocols.include?(i); @protocol = i; break; }
          elsif env[PROTOCOL_NAME_IN].is_a?(Array) # for multiple headers such as: "soap" , "json", "foo"
            env[PROTOCOL_NAME_IN].each { |i| next unless protocols.include?(i); @protocol = i; break; }
          end
        end
      end

      def possible?
        true
      end

      def alive?
        websocket && websocket.open?
      end

      def transmit(data)
        return false unless websocket
        case data
        when Numeric then websocket.write(data.to_s)
        when String  then websocket.write(data)
        when Array   then websocket.write(data.pack("C*"))
        else false
        end
      end

      def close
        websocket.close
      end

      def protocol
        @protocol
      end

      def rack_response
        return [101, { PROTOCOL_NAME_OUT => @protocol }, []] if @protocol
        [101, {}, []]
      end

      def on_open(client)
        @websocket = client
        @event_target.on_open
      end
      def on_close(client)
        # @event_target.on_error(message) # Rack doesn't support error notifications, they are irrelevant network details.
        @event_target.on_close(1000, CLOSE_REASON)
      end
      def on_message(client, data)
        @event_target.on_message(data)
      end

      def self.okay?(env)
        env[UPGRADE_EXISTS] == :websocket
      end

      private
        attr_reader :websocket
    end
  end
end
