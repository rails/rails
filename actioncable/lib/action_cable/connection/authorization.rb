module ActionCable
  module Connection
    module Authorization
      class UnauthorizedError < StandardError; end

      private
        def reject_unauthorized_connection
          logger.error "An unauthorized connection attempt was rejected"
          raise UnauthorizedError
        end
    end
  end
end
