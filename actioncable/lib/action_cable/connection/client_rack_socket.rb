# frozen_string_literal: true

module ActionCable
  module Connection
    # Wrap the `rack.upgrade?` API as an alternative to using `websocket/driver` and `nio4r`
    #
    # The `rack.upgrade?` approach detailed here: https://github.com/rack/rack/pull/1272
    class ClientRackSocket # :nodoc:
      def self.accept?(env)
        env["rack.upgrade?"] == :websocket
      end

      def self.attempt(env, event_target, event_loop, protocols)
        accept?(env) && new(env, event_target, event_loop, protocols)
      end

      attr_reader :protocol

      def initialize(env, event_target, event_loop, protocols)
        env["rack.upgrade"] = self
        @event_target = event_target
        @protocol = nil
        @websocket = nil
        request_protocols = env["HTTP_SEC_WEBSOCKET_PROTOCOL"]
        unless request_protocols.nil?
          request_protocols = request_protocols.split(/,\s?/) if request_protocols.is_a?(String)
          request_protocols.each do |request_protocol|
            break(@protocol = request_protocol) if protocols.include?(request_protocol)
          end
        end
      end

      def alive?
        websocket&.open?
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
        websocket&.close
      end

      def rack_response
        if protocol
          [101, { "Sec-Websocket-Protocol" => protocol }, []]
        else
          [101, {}, []]
        end
      end

      def on_open(client)
        @websocket = client
        @event_target.on_open
      end

      def on_close(client)
        @event_target.on_close(1000, "")
      end

      def on_message(client, data)
        @event_target.on_message(data)
      end

      private
        attr_reader :websocket
    end
  end
end
