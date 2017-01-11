module ActionCable
  module Client
    # Collection class for all the client streams.
    class Streams
      def initialize(connection)
        @connection = connection
      end
      # Start streaming from broadcasting to the channel.
      # Optional callback can be probived to be invoked after successful subscription to the stream.
      def add(channel_id, broadcasting, handler, &callback)
        streams[channel_id] ||= []

        worker_handler = worker_pool_stream_handler(handler)

        streams[channel_id] << [ broadcasting, worker_handler ]

        connection.server.event_loop.post do
          pubsub.subscribe(broadcasting, handler, callback)
        end
      end

      # Stop all streams for the channel
      def remove_all(channel_id)
        streams.fetch(channel_id) { [] }.each do |broadcasting, callback|
          pubsub.unsubscribe broadcasting, callback
        end
        streams.delete(channel_id)
      end

      private
        attr_reader :connection

        delegate :pubsub, to: :connection

        def streams
          @_streams ||= {}
        end

        # Always wrap the outermost handler to invoke the user handler on the
        # worker pool rather than blocking the event loop.
        def worker_pool_stream_handler(handler)
          -> message do
            connection.worker_pool.async_invoke handler, :call, message, connection: connection
          end
        end
    end
  end
end
