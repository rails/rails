module ActiveRecord
  module ConnectionAdapters
    class TransactionState
      def finalized?;  false; end
      def committed?;  false; end
      def rolledback?; false; end
      def completed?;  false; end

      class Committed < TransactionState
        def finalized?; true; end
        def committed?; true; end
        def completed?; true; end
      end

      class RolledBack < TransactionState
        def finalized?;  true; end
        def rolledback?; true; end
        def completed?;  true; end
      end

      ROLLED_BACK = RolledBack.new
      COMMITTED   = Committed.new
      NULL        = TransactionState.new

      def self.rolled_back; ROLLED_BACK; end
      def self.committed;   COMMITTED; end
      def self.null;        NULL; end
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
        @state = TransactionState.null
        @records = []
        @joinable = options.fetch(:joinable, true)
      end

      def add_record(record)
        records << record
      end

      def rollback
        @state = TransactionState.rolled_back
      end

      def rolledback?
        @state.rolledback?
      end

      def finalized?
        @state.finalized?
      end

      def rollback_records
        ite = records.uniq
        while record = ite.shift
          record.rolledback!(force_restore_state: full_rollback?)
        end
      ensure
        ite.each do |i|
          i.rolledback!(force_restore_state: full_rollback?, should_run_callbacks: false)
        end
      end

      def commit
        @state = TransactionState.committed
      end

      def before_commit_records
        records.uniq.each(&:before_committed!)
      end

      def commit_records
        ite = records.uniq
        while record = ite.shift
          record.committed!
        end
      ensure
        ite.each do |i|
          i.committed!(should_run_callbacks: false)
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
        connection.rollback_to_savepoint(savepoint_name)
        super
      end

      def commit
        connection.release_savepoint(savepoint_name)
        super
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
        connection.rollback_db_transaction
        super
      end

      def commit
        connection.commit_db_transaction
        super
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
        inner_transaction = @stack.pop

        if current_transaction.joinable?
          inner_transaction.commit
          inner_transaction.records.each do |r|
            r.add_to_transaction
          end
        else
          inner_transaction.before_commit_records
          inner_transaction.commit
          inner_transaction.commit_records
        end
      end

      def rollback_transaction(transaction = nil)
        transaction ||= @stack.pop
        transaction.rollback
        transaction.rollback_records
      end

      def within_new_transaction(options = {})
        transaction = begin_transaction options
        yield
      rescue Exception => error
        rollback_transaction if transaction
        raise
      ensure
        unless error
          if Thread.current.status == 'aborting'
            rollback_transaction if transaction
          else
            begin
              commit_transaction
            rescue Exception
              rollback_transaction(transaction) unless transaction.state.completed?
              raise
            end
          end
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
