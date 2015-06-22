module ActionCable
  module Connection
    class Processor
      def initialize(connection)
        @connection = connection
        @pending_messages = []
      end

      def handle(message)
        if valid? message
          if ready?
            process message
          else
            queue message
          end
        end
      end

      def ready?
        @ready
      end

      def ready!
        @ready = true
        handle_pending_messages
      end

      private
        attr_reader :connection
        attr_accessor :pending_messages

        def process(message)
          connection.send_async :receive, message
        end

        def queue(message)
          pending_messages << message
        end

        def valid?(message)
          if message.is_a?(String)
            true
          else
            connection.logger.error "Couldn't handle non-string message: #{message.class}"
            false
          end
        end

        def handle_pending_messages
          process pending_messages.shift until pending_messages.empty?
        end
    end
  end
end