module ActionCable
  module Connection
    module Authorization
      class UnauthorizedError < StandardError; end

      # Closes the \WebSocket connection if it is open and returns a 404 "File not Found" response.
      def reject_unauthorized_connection
        logger.error "An unauthorized connection attempt was rejected"
        raise UnauthorizedError
      end
    end
  end
end