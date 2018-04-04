# frozen_string_literal: true

require "websocket/driver"

module ActionCable
  module Connection
    #--
    # This class is heavily based on faye-websocket-ruby
    #
    # Copyright (c) 2010-2015 James Coglan
    class ClientSocket # :nodoc:
      def self.determine_url(env)
        scheme = secure_request?(env) ? "wss:" : "ws:"
        "#{ scheme }//#{ env['HTTP_HOST'] }#{ env['REQUEST_URI'] }"
      end

      def self.secure_request?(env)
        return true if env["HTTPS"] == "on"
        return true if env["HTTP_X_FORWARDED_SSL"] == "on"
        return true if env["HTTP_X_FORWARDED_SCHEME"] == "https"
        return true if env["HTTP_X_FORWARDED_PROTO"] == "https"
        return true if env["rack.url_scheme"] == "https"

        false
      end

      CONNECTING = 0
      OPEN       = 1
      CLOSING    = 2
      CLOSED     = 3

      attr_reader :env, :url

      def initialize(env, event_target, event_loop, protocols)
        @ping_times = 0
        @env          = env
        @event_target = event_target
        @event_loop   = event_loop

        @url = ClientSocket.determine_url(@env)

        @driver = @driver_started = nil
        @close_params = ["", 1006]

        @ready_state = CONNECTING

        # The driver calls +env+, +url+, and +write+
        @driver = ::WebSocket::Driver.rack(self, protocols: protocols)

        @driver.on(:open)    { |e| open }
        @driver.on(:message) { |e| receive_message(e.data) }
        @driver.on(:close)   { |e| begin_close(e.reason, e.code) }
        @driver.on(:error)   { |e| emit_error(e.message) }

        @stream = ActionCable::Connection::Stream.new(@event_loop, self)
      end

      def start_driver
        return if @driver.nil? || @driver_started
        @stream.hijack_rack_socket

        if callback = @env["async.callback"]
          callback.call([101, {}, @stream])
        end

        @driver_started = true
        @driver.start
      end

      def ping
        return false if @ready_state > OPEN
        @ping_times += 1
        result = @driver.ping('pong') do
          @ping_times = 0
        end
        client_gone if @ping_times > 5
      end

      def rack_response
        start_driver
        [ -1, {}, [] ]
      end

      def write(data)
        @stream.write(data)
      rescue => e
        emit_error e.message
      end

      def transmit(message)
        return false if @ready_state > OPEN
        case message
        when Numeric then @driver.text(message.to_s)
        when String  then @driver.text(message)
        when Array   then @driver.binary(message)
        else false
        end
      end

      def close(code = nil, reason = nil)
        code   ||= 1000
        reason ||= ""

        unless code == 1000 || (code >= 3000 && code <= 4999)
          raise ArgumentError, "Failed to execute 'close' on WebSocket: " \
                               "The code must be either 1000, or between 3000 and 4999. " \
                               "#{code} is neither."
        end

        @ready_state = CLOSING unless @ready_state == CLOSED
        @driver.close(reason, code)
      end

      def parse(data)
        @driver.parse(data)
      end

      def client_gone
        finalize_close
      end

      def alive?
        @ready_state == OPEN
      end

      def protocol
        @driver.protocol
      end

      private
        def open
          return unless @ready_state == CONNECTING
          @ready_state = OPEN

          @event_target.on_open
        end

        def receive_message(data)
          return unless @ready_state == OPEN

          @event_target.on_message(data)
        end

        def emit_error(message)
          return if @ready_state >= CLOSING

          @event_target.on_error(message)
        end

        def begin_close(reason, code)
          return if @ready_state == CLOSED
          @ready_state = CLOSING
          @close_params = [reason, code]

          @stream.shutdown if @stream
          finalize_close
        end

        def finalize_close
          return if @ready_state == CLOSED
          @ready_state = CLOSED

          @event_target.on_close(*@close_params)
        end
    end
  end
end
