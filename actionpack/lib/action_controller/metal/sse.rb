require 'securerandom'

module ActionController
  module ServerSentEvents
    OPTIONAL_SSE_FIELDS = [:name, :id, :retry]
    REQUIRED_SSE_FIELDS = [:data]

    SSE_FIELDS = OPTIONAL_SSE_FIELDS + REQUIRED_SSE_FIELDS

    class << self
      @@sse_server = nil

      def start_server
        @@sse_server ||= SseServer.new()
        @@sse_server.start
      end

      def stop_server
        started_server?
        @@sse_server.stop
      end

      def send_sse(sse)
        started_server?
        @@sse_server.send_sse(sse)
      end

      def send_sse_hash(sse_hash)
        started_server?
        @@sse_server.send_sse_hash(sse_hash)
      end

      def subscribe(response)
        started_server?
        @@sse_server.subscribe(response)
      end

      def unsubscribe
        started_server?
        @@sse_server.unsubscribe
      end

      private

      def started_server?
        unless @@sse_server && @@sse_server.continue_sending
          raise ArgumentError, "SSE server has not been started. You must call start_server first."
        end
      end
    end

    class SseServer
      attr_reader :continue_sending

      def initialize(subscriber = nil)
        @sse_queue = Queue.new
        @continue_sending = false
        @subscriber = subscriber
      end

      # Sends an sse to the browser. Must be called after start_sse_server
      # has been called and while the sse server is still running.
      def send_sse(sse)
        send_sse_hash(sse.to_payload_hash)
      end

      def empty_queue?
        @sse_queue.empty?
      end

      # Subscribes a response to receive sse's.
      def subscribe(response)
        response.headers['Content-Type'] = 'text/event-stream'
        @subscriber = response
      end

      # Unsubscribes a response from receiving sse's.
      def unsubscribe
        if @subscriber
          @subscriber.stream.close
          @subscriber = nil
        end
      end

      # Sends a hash of sse options to the browser. Must be in the following
      # format:
      #
      # {:id => id, :name => event_name, :data => sse_data}
      #
      # The minimum requirements of the hash are the it contains a :data field.
      # All other fields are optional.
      def send_sse_hash(sse_hash)
        REQUIRED_SSE_FIELDS.each do |field|
          unless sse_hash[field]
            raise ArgumentError, "Must send an SSE with a '#{field}' field."
          end
        end
        @sse_queue.push(sse_hash)
      end

      # Starts the sse server and will begin sending any events that are are
      # sent via the send_sse method. Returns if the server is already sending.
      def start
        return if @continue_sending

        @continue_sending = true
        Thread.new do
          while @continue_sending
            unless empty_queue?
              payload = @sse_queue.pop
              stream_sse_payload(payload)
            end
          end

          unsubscribe
        end
      end

      # Stops the server from sending any sse events.
      def stop
        @continue_sending = false
      end

      private

      # Sends the sse over the rails server to the browser.
      def stream_sse_payload(payload)
        message = convert_payload_to_message(payload)

        begin
          @subscriber.stream.write(message)
        rescue IOError
          # The stream has been closed
          unsubscribe
        end
      end

      # Converts a payload received from an sse notification into an sse
      # message to be sent over http
      def convert_payload_to_message(payload)
        message_array = []
        SSE_FIELDS.each do |field|
          value = if payload[field]
            payload[field]
          elsif field == :id
            SecureRandom.hex
          end

          message_array << "\n#{field}: #{value}" if value
        end

        message_array << "\n\n"
        message_array.join("")
      end
    end

    class ServerSentEvent
      SSE_FIELDS.each do |field|
        attr_reader field
      end

      def initialize(data, opts = {})
        @data = data
        SSE_FIELDS.each do |field|
          instance_variable_set("@#{field}", opts[field])
        end
      end

      def to_payload_hash
        payload = {}
        SSE_FIELDS.each do |field|
          payload[field] = send(field)
        end

        payload
      end
    end
  end
end
