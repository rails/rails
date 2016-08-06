module ActiveRecord
  module ConnectionAdapters
    class TransactionState
      VALID_STATES = Set.new([:committed, :rolledback, nil])

      def initialize(state = nil)
        @state = state
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

      def completed?
        committed? || rolledback?
      end

      def set_state(state)
        unless VALID_STATES.include?(state)
          raise ArgumentError, "Invalid transaction state: #{state}"
        end
        @state = state
      end
    end

    class NullTransaction #:nodoc:
      def initialize; end
      def state; end
      def closed?; true; end
      def open?; false; end
      def joinable?; false; end
      def add_record(record); end
    end

    class Transaction #:nodoc:

      attr_reader :connection, :state, :records, :savepoint_name
      attr_writer :joinable

      def initialize(connection, options, run_commit_callbacks: false)
        @connection = connection
        @state = TransactionState.new
        @records = []
        @joinable = options.fetch(:joinable, true)
        @run_commit_callbacks = run_commit_callbacks
      end

      def add_record(record)
        records << record
      end

      def rollback
        @state.set_state(:rolledback)
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
        @state.set_state(:committed)
      end

      def before_commit_records
        records.uniq.each(&:before_committed!) if @run_commit_callbacks
      end

      def commit_records
        ite = records.uniq
        while record = ite.shift
          if @run_commit_callbacks
            record.committed!
          else
            # if not running callbacks, only adds the record to the parent transaction
            record.add_to_transaction
          end
        end
      ensure
        ite.each { |i| i.committed!(should_run_callbacks: false) }
      end

      def full_rollback?; true; end
      def joinable?; @joinable; end
      def closed?; false; end
      def open?; !closed?; end
    end

    class SavepointTransaction < Transaction

      def initialize(connection, savepoint_name, options, *args)
        super(connection, options, *args)
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

      def initialize(connection, options, *args)
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
        run_commit_callbacks = !current_transaction.joinable?
        transaction =
          if @stack.empty?
            RealTransaction.new(@connection, options, run_commit_callbacks: run_commit_callbacks)
          else
            SavepointTransaction.new(@connection, "active_record_#{@stack.size}", options,
                                     run_commit_callbacks: run_commit_callbacks)
          end

        @stack.push(transaction)
        transaction
      end

      def commit_transaction
        transaction = @stack.last

        begin
          transaction.before_commit_records
        ensure
          @stack.pop
        end

        transaction.commit
        transaction.commit_records
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
        if transaction
          rollback_transaction
          after_failure_actions(transaction, error)
        end
        raise
      ensure
        unless error
          if Thread.current.status == "aborting"
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

        # Deallocate invalidated prepared statements outside of the transaction
        def after_failure_actions(transaction, error)
          return unless transaction.is_a?(RealTransaction)
          return unless error.is_a?(ActiveRecord::PreparedStatementCacheExpired)
          @connection.clear_cache!
        end

    end
  end
end
