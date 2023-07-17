# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogy
      module Errors
        # ServerShutdown will be raised when the database server was shutdown.
        class ServerShutdown < ActiveRecord::ConnectionFailed
        end

        # ServerLost will be raised when the database connection was lost.
        class ServerLost < ActiveRecord::ConnectionFailed
        end

        # ServerGone will be raised when the database connection is gone.
        class ServerGone < ActiveRecord::ConnectionFailed
        end

        # BrokenPipe will be raised when a system process connection fails.
        class BrokenPipe < ActiveRecord::ConnectionFailed
        end

        # SocketError will be raised when Ruby encounters a network error.
        class SocketError < ActiveRecord::ConnectionFailed
        end

        # ConnectionResetByPeer will be raised when a network connection is closed
        # outside the sytstem process.
        class ConnectionResetByPeer < ActiveRecord::ConnectionFailed
        end

        # ClosedConnection will be raised when the Trilogy encounters a closed
        # connection.
        class ClosedConnection < ActiveRecord::ConnectionFailed
        end

        # InvalidSequenceId will be raised when Trilogy ecounters an invalid sequence
        # id.
        class InvalidSequenceId < ActiveRecord::ConnectionFailed
        end

        # UnexpectedPacket will be raised when Trilogy ecounters an unexpected
        # response packet.
        class UnexpectedPacket < ActiveRecord::ConnectionFailed
        end
      end
    end
  end
end
