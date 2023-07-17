# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogy
      class LostConnectionExceptionTranslator
        attr_reader :exception, :message, :error_number

        def initialize(exception, message, error_number, connection_pool)
          @exception = exception
          @message = message
          @error_number = error_number
          @connection_pool = connection_pool
        end

        def translate
          translate_database_exception || translate_ruby_exception || translate_trilogy_exception
        end

        private
          ER_SERVER_SHUTDOWN = 1053
          CR_SERVER_LOST = 2013
          CR_SERVER_LOST_EXTENDED = 2055
          CR_SERVER_GONE_ERROR = 2006

          def translate_database_exception
            case error_number
            when ER_SERVER_SHUTDOWN
              Errors::ServerShutdown.new(message, connection_pool: @connection_pool)
            when CR_SERVER_LOST, CR_SERVER_LOST_EXTENDED
              Errors::ServerLost.new(message, connection_pool: @connection_pool)
            when CR_SERVER_GONE_ERROR
              Errors::ServerGone.new(message, connection_pool: @connection_pool)
            end
          end

          def translate_ruby_exception
            case exception
            when Errno::EPIPE
              Errors::BrokenPipe.new(message, connection_pool: @connection_pool)
            when SocketError, IOError
              Errors::SocketError.new(message, connection_pool: @connection_pool)
            when ::Trilogy::ConnectionError
              if message.include?("Connection reset by peer")
                Errors::ConnectionResetByPeer.new(message, connection_pool: @connection_pool)
              end
            end
          end

          def translate_trilogy_exception
            return unless exception.is_a?(::Trilogy::Error)

            case message
            when /TRILOGY_CLOSED_CONNECTION/
              Errors::ClosedConnection.new(message, connection_pool: @connection_pool)
            when /TRILOGY_INVALID_SEQUENCE_ID/
              Errors::InvalidSequenceId.new(message, connection_pool: @connection_pool)
            when /TRILOGY_UNEXPECTED_PACKET/
              Errors::UnexpectedPacket.new(message, connection_pool: @connection_pool)
            end
          end
      end
    end
  end
end
