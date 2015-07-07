module ActionCable
  module Channel
    module Streams
      extend ActiveSupport::Concern

      included do
        on_unsubscribe :stop_all_streams
      end

      def stream_from(broadcasting, callback = nil)
        callback ||= default_stream_callback(broadcasting)

        streams << [ broadcasting, callback ]
        pubsub.subscribe broadcasting, &callback

        logger.info "#{self.class.name} is streaming from #{broadcasting}"
      end

      def stop_all_streams
        streams.each do |broadcasting, callback|
          pubsub.unsubscribe_proc broadcasting, callback
          logger.info "#{self.class.name} stopped streaming from #{broadcasting}"
        end
      end

      private
        delegate :pubsub, to: :connection

        def streams
          @_streams ||= []
        end

        def default_stream_callback(broadcasting)
          -> (message) do
            transmit ActiveSupport::JSON.decode(message), via: "streamed from #{broadcasting}"
          end
        end
    end
  end
end
