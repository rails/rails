module ActionCable
  module Connection
    # Collection class for all the client streams.
    class Streams
      def initialize(socket)
        @socket = socket
      end
      # Start streaming from broadcasting to the channel.
      # Optional callback can be probived to be invoked after successful subscription to the stream.
      def add(channel_id, broadcasting, handler, &callback)
        streams[channel_id] ||= []

        worker_handler = worker_pool_stream_handler(handler)

        streams[channel_id] << [ broadcasting, worker_handler ]

        socket.server.event_loop.post do
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
        attr_reader :socket

        delegate :pubsub, to: :socket

        def streams
          @_streams ||= {}
        end

        # Always wrap the outermost handler to invoke the user handler on the
        # worker pool rather than blocking the event loop.
        def worker_pool_stream_handler(handler)
          -> message do
            socket.worker_pool.async_invoke handler, :call, message, socket: socket
          end
        end
    end
  end
end
