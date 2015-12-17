module ActionCable
  module Connection
    # Allows us to buffer messages received from the WebSocket before the Connection has been fully initialized and is ready to receive them.
    # Entirely internal operation and should not be used directly by the user.
    class MessageBuffer
      def initialize(connection)
        @connection = connection
        @buffered_messages = []
      end

      def append(message)
        if valid? message
          if processing?
            receive message
          else
            buffer message
          end
        else
          connection.logger.error "Couldn't handle non-string message: #{message.class}"
        end
      end

      def processing?
        @processing
      end

      def process!
        @processing = true
        receive_buffered_messages
      end

      protected
        attr_reader :connection
        attr_accessor :buffered_messages

      private
        def valid?(message)
          message.is_a?(String)
        end

        def receive(message)
          connection.send_async :receive, message
        end

        def buffer(message)
          buffered_messages << message
        end

        def receive_buffered_messages
          receive buffered_messages.shift until buffered_messages.empty?
        end
    end
  end
end
