require 'securerandom'

module ActionController

  # This class is an initial implementation of HTML5 SSE for rails
  # Currently we provide 2 kinds of ways to implement a SSE server
  # The first is controller level SSE, in which we do not distinguish clients 
  # and will send data to all the clients that subscribe the same sse source
  # The second is client level SSE, which we DO distinguish clients and
  # the data sent to different client can be totally different.
  #
  # Controlller level SSE:
  # 
  # class MySSE < ActionController::Base
  #   include ActionController::Live
  #   include ActionController::ServerSentEvents
  #   extend ActionController::ServerSentEvents::ClassMethods
  # end
  # 
  # in this way, an action named sse_source will be created automaticlly and you 
  # can use MySSE.send_sse or MySSE.send_sse_hash to send event to all clients that
  # subscribed the sse_source
  #
  #
  # Client level SSE(Session awared):
  # 
  # class MySSE < ActionController::Base
  #   include ActionController::Live
  #   include ActionController::ServerSentEvents
  # 
  #   def event
  #     start_serve do |sse_client|
  #       # we can access some session variables here
  #       sse_client.send_sse sse
  #       sse_client.send_sse_hash :data => "david"
  #     end
  #     
  #   end
  # end
  #
  # Please note that Controller level SSE and Client level SSE are not meant to
  # work together in the same controller.
  module ServerSentEvents
    OPTIONAL_SSE_FIELDS = [:name, :id, :retry]
    REQUIRED_SSE_FIELDS = [:data]

    SSE_FIELDS = OPTIONAL_SSE_FIELDS + REQUIRED_SSE_FIELDS

    module ClassMethods
      @@sse_clients = {}

      def self.extended(base)
        base.class_exec do
          # the entry point for a Controller level SSE source
          def sse_source
            start_serve self.class.client_list
          end
        end

        @@sse_clients[base] = []
      end

      def send_sse(sse)
        client_list.each do |client|
          begin
            client.send_sse(sse)
          rescue IOError
          end
        end
      end

      def send_sse_hash(sse_hash)
        client_list.each do |client|
          begin
            client.send_sse_hash(sse_hash)
          rescue IOError
          end
        end
      end

      def client_list
        @@sse_clients[self]
      end
    end

    def start_serve(client_list = nil, &blk)
      client = SseClient.new
      client.subscribe response
      client_list << client if client_list

      Thread.new do 
        begin
          blk.call client if block_given?
        ensure
        end
      end

      client.start_serve
    ensure
      client_list.delete_if {|it| it == client} if client_list
      response.stream.close
    end


    class SseClient
     
      def initialize(opts = {})
        @sse_queue = Queue.new
        @subscriber = opts[:subscriber]
        @stopped = true

        if opts[:start_on_initialize]
          start_serve
        end
      end

      # Subscribes a response to receive sse's.
      def subscribe(response)
        response.headers['Content-Type'] = 'text/event-stream'
        @subscriber = response
      end

      # Sends an sse to the browser. Must be called after start_sse_server
      # has been called and while the sse server is still running.
      #
      # The input must be an object of class
      # ActionController::ServerSentEvents::ServerSentEvent
      # and it must have the +to_payload_hash+ method.
      def send_sse(sse)
        send_sse_hash(sse.to_payload_hash)
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
        raise IOError, "Unable to send SSE to client" if @stopped
        @sse_queue.push(sse_hash)
      end

      # Starts the sse server and will begin sending any events that are are
      # sent via the send_sse method. Returns if the server is already sending.
      def start_serve
        @stopped = false
        while payload = @sse_queue.pop # if queue is empty, we'll block here
          stream_sse_payload(payload)
        end
      ensure
        @stopped = true
      end

      private

      # Sends the sse over the rails server to the browser.
      def stream_sse_payload(payload)
        message = convert_payload_to_message(payload)

        @subscriber.stream.write(message)
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
        OPTIONAL_SSE_FIELDS.each do |field|
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
