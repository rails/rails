module ActiveRecord
  module ConnectionAdapters
    class TransactionManager #:nodoc:
      def initialize(connection)
        @stack = []
        @connection = connection
      end

      def begin_transaction(options = {})
        transaction =
          if @stack.empty?
            RealTransaction.new(@connection, current_transaction, options)
          else
            SavepointTransaction.new(@connection, current_transaction, options)
          end

        @stack.push(transaction)
        transaction
      end

      def commit_transaction
        @stack.pop.commit
      end

      def rollback_transaction
        @stack.pop.rollback
      end

      def within_new_transaction(options = {})
        transaction = begin_transaction options
        yield
      rescue Exception => error
        transaction.rollback if transaction
        raise
      ensure
        begin
          transaction.commit unless error
        rescue Exception
          transaction.rollback
          raise
        ensure
          @stack.pop if transaction
        end
      end

      def open_transactions
        @stack.size
      end

      def current_transaction
        @stack.last || closed_transaction
      end

      private

        def closed_transaction
          @closed_transaction ||= ClosedTransaction.new(@connection)
        end
    end

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

      def finalized?
        @state
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
        @joinable  = options.fetch(:joinable, true)
      end


      def joinable?
        @joinable
      end

      def number
        parent.number + 1
      end

      def begin(options = {})
        SavepointTransaction.new(connection, self, options)
      end

      def rollback
        perform_rollback
        parent
      end

      def commit
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
      attr_reader :savepoint_name

      def initialize(connection, parent, options = {})
        if options[:isolation]
          raise ActiveRecord::TransactionIsolationError, "cannot set transaction isolation in a nested transaction"
        end

        super

        @savepoint_name = "active_record_#{number}"
        connection.create_savepoint(@savepoint_name)
      end

      def perform_rollback
        connection.rollback_to_savepoint(@savepoint_name)
        rollback_records
      end

      def perform_commit
        @state.set_state(:committed)
        @state.parent = parent.state
        connection.release_savepoint(@savepoint_name)
      end
    end
  end
end
