module ActiveRecord
  module ConnectionAdapters
    class TransactionState
      attr_reader :parent

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

    class NullTransaction #:nodoc:
      def initialize; end
      def closed?; true; end
      def open?; false; end
      def joinable?; false; end
      def add_record(record); end
    end

    class Transaction #:nodoc:

      attr_reader :connection, :state, :records, :savepoint_name
      attr_writer :joinable

      def initialize(connection, options)
        @connection = connection
        @state = TransactionState.new
        @records = []
        @joinable = options.fetch(:joinable, true)
      end

      def add_record(record)
        if record.has_transactional_callbacks?
          records << record
        else
          record.set_transaction_state(@state)
        end
      end

      def rollback
        @state.set_state(:rolledback)
      end

      def rollback_records
        records.uniq.each do |record|
          begin
            record.rolledback! full_rollback?
          rescue => e
            record.logger.error(e) if record.respond_to?(:logger) && record.logger
          end
        end
      end

      def commit
        @state.set_state(:committed)
      end

      def commit_records
        records.uniq.each do |record|
          begin
            record.committed!
          rescue => e
            record.logger.error(e) if record.respond_to?(:logger) && record.logger
          end
        end
      end

      def full_rollback?; true; end
      def joinable?; @joinable; end
      def closed?; false; end
      def open?; !closed?; end
    end

    class SavepointTransaction < Transaction

      def initialize(connection, savepoint_name, options)
        super(connection, options)
        if options[:isolation]
          raise ActiveRecord::TransactionIsolationError, "cannot set transaction isolation in a nested transaction"
        end
        connection.create_savepoint(@savepoint_name = savepoint_name)
      end

      def rollback
        super
        connection.rollback_to_savepoint(savepoint_name)
        rollback_records
      end

      def commit
        super
        connection.release_savepoint(savepoint_name)
      end

      def full_rollback?; false; end
    end

    class RealTransaction < Transaction

      def initialize(connection, options)
        super
        if options[:isolation]
          connection.begin_isolated_db_transaction(options[:isolation])
        else
          connection.begin_db_transaction
        end
      end

      def rollback
        super
        connection.rollback_db_transaction
        rollback_records
      end

      def commit
        super
        connection.commit_db_transaction
        commit_records
      end
    end

    class TransactionManager #:nodoc:
      def initialize(connection)
        @stack = []
        @connection = connection
      end

      def begin_transaction(options = {})
        transaction =
          if @stack.empty?
            RealTransaction.new(@connection, options)
          else
            SavepointTransaction.new(@connection, "active_record_#{@stack.size}", options)
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
        @stack.last || NULL_TRANSACTION
      end

      private
        NULL_TRANSACTION = NullTransaction.new
    end
  end
end
