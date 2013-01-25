module ActiveRecord
  module ConnectionAdapters
    class Transaction #:nodoc:
      attr_reader :connection

      def initialize(connection)
        @connection = connection
        @state = TransactionState.new
      end

      def state
        @state
      end
    end

    class TransactionState
      attr_accessor :parent

      VALID_STATES = Set.new([:committed, :rolledback, nil])

      def initialize(state = nil)
        @state = state
        @parent = nil
      end

      def committed?
        @state == :committed
      end

      def rolledback?
        @state == :rolledback
      end

      def set_state(state)
        if !VALID_STATES.include?(state)
          raise ArgumentError, "Invalid transaction state: #{state}"
        end
        @state = state
      end
    end

    class ClosedTransaction < Transaction #:nodoc:
      def number
        0
      end

      def begin(options = {})
        RealTransaction.new(connection, self, options)
      end

      def closed?
        true
      end

      def open?
        false
      end

      def joinable?
        false
      end

      # This is a noop when there are no open transactions
      def add_record(record)
      end
    end

    class OpenTransaction < Transaction #:nodoc:
      attr_reader :parent, :records
      attr_writer :joinable

      def initialize(connection, parent, options = {})
        super connection

        @parent    = parent
        @records   = []
        @finishing = false
        @joinable  = options.fetch(:joinable, true)
      end

      # This state is necesarry so that we correctly handle stuff that might
      # happen in a commit/rollback. But it's kinda distasteful. Maybe we can
      # find a better way to structure it in the future.
      def finishing?
        @finishing
      end

      def joinable?
        @joinable && !finishing?
      end

      def number
        if finishing?
          parent.number
        else
          parent.number + 1
        end
      end

      def begin(options = {})
        if finishing?
          parent.begin
        else
          SavepointTransaction.new(connection, self, options)
        end
      end

      def rollback
        @finishing = true
        perform_rollback
        parent
      end

      def commit
        @finishing = true
        perform_commit
        parent
      end

      def add_record(record)
        if record.has_transactional_callbacks?
          records << record
        else
          record.set_transaction_state(@state)
        end
      end

      def rollback_records
        @state.set_state(:rolledback)
        records.uniq.each do |record|
          begin
            record.rolledback!(parent.closed?)
          rescue => e
            record.logger.error(e) if record.respond_to?(:logger) && record.logger
          end
        end
      end

      def commit_records
        @state.set_state(:committed)
        records.uniq.each do |record|
          begin
            record.committed!
          rescue => e
            record.logger.error(e) if record.respond_to?(:logger) && record.logger
          end
        end
      end

      def closed?
        false
      end

      def open?
        true
      end
    end

    class RealTransaction < OpenTransaction #:nodoc:
      def initialize(connection, parent, options = {})
        super

        if options[:isolation]
          connection.begin_isolated_db_transaction(options[:isolation])
        else
          connection.begin_db_transaction
        end
      end

      def perform_rollback
        connection.rollback_db_transaction
        rollback_records
      end

      def perform_commit
        connection.commit_db_transaction
        commit_records
      end
    end

    class SavepointTransaction < OpenTransaction #:nodoc:
      def initialize(connection, parent, options = {})
        if options[:isolation]
          raise ActiveRecord::TransactionIsolationError, "cannot set transaction isolation in a nested transaction"
        end

        super
        connection.create_savepoint
      end

      def perform_rollback
        connection.rollback_to_savepoint
        rollback_records
      end

      def perform_commit
        @state.set_state(:committed)
        @state.parent = parent.state
        connection.release_savepoint
      end
    end
  end
end
