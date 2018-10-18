# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class TransactionState
      def initialize(state = nil)
        @state = state
        @children = []
      end

      def add_child(state)
        @children << state
      end

      def finalized?
        @state
      end

      def committed?
        @state == :committed || @state == :fully_committed
      end

      def fully_committed?
        @state == :fully_committed
      end

      def rolledback?
        @state == :rolledback || @state == :fully_rolledback
      end

      def fully_rolledback?
        @state == :fully_rolledback
      end

      def fully_completed?
        completed?
      end

      def completed?
        committed? || rolledback?
      end

      def set_state(state)
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          The set_state method is deprecated and will be removed in
          Rails 6.0. Please use rollback! or commit! to set transaction
          state directly.
        MSG
        case state
        when :rolledback
          rollback!
        when :committed
          commit!
        when nil
          nullify!
        else
          raise ArgumentError, "Invalid transaction state: #{state}"
        end
      end

      def rollback!
        @children.each { |c| c.rollback! }
        @state = :rolledback
      end

      def full_rollback!
        @children.each { |c| c.rollback! }
        @state = :fully_rolledback
      end

      def commit!
        @state = :committed
      end

      def full_commit!
        @state = :fully_committed
      end

      def nullify!
        @state = nil
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
      attr_reader :connection, :state, :records, :savepoint_name, :isolation_level

      def initialize(connection, options, run_commit_callbacks: false)
        @connection = connection
        @state = TransactionState.new
        @records = []
        @isolation_level = options[:isolation]
        @materialized = false
        @joinable = options.fetch(:joinable, true)
        @run_commit_callbacks = run_commit_callbacks
      end

      def add_record(record)
        records << record
      end

      def materialize!
        @materialized = true
      end

      def materialized?
        @materialized
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
      def initialize(connection, savepoint_name, parent_transaction, *args)
        super(connection, *args)

        parent_transaction.state.add_child(@state)

        if isolation_level
          raise ActiveRecord::TransactionIsolationError, "cannot set transaction isolation in a nested transaction"
        end

        @savepoint_name = savepoint_name
      end

      def materialize!
        connection.create_savepoint(savepoint_name)
        super
      end

      def rollback
        connection.rollback_to_savepoint(savepoint_name) if materialized?
        @state.rollback!
      end

      def commit
        connection.release_savepoint(savepoint_name) if materialized?
        @state.commit!
      end

      def full_rollback?; false; end
    end

    class RealTransaction < Transaction
      def materialize!
        if isolation_level
          connection.begin_isolated_db_transaction(isolation_level)
        else
          connection.begin_db_transaction
        end

        super
      end

      def rollback
        connection.rollback_db_transaction if materialized?
        @state.full_rollback!
      end

      def commit
        connection.commit_db_transaction if materialized?
        @state.full_commit!
      end
    end

    class TransactionManager #:nodoc:
      def initialize(connection)
        @stack = []
        @connection = connection
        @has_unmaterialized_transactions = false
        @materializing_transactions = false
        @lazy_transactions_enabled = true
      end

      def begin_transaction(options = {})
        @connection.lock.synchronize do
          run_commit_callbacks = !current_transaction.joinable?
          transaction =
            if @stack.empty?
              RealTransaction.new(@connection, options, run_commit_callbacks: run_commit_callbacks)
            else
              SavepointTransaction.new(@connection, "active_record_#{@stack.size}", @stack.last, options,
                                       run_commit_callbacks: run_commit_callbacks)
            end

          transaction.materialize! unless @connection.supports_lazy_transactions? && lazy_transactions_enabled?
          @stack.push(transaction)
          @has_unmaterialized_transactions = true if @connection.supports_lazy_transactions?
          transaction
        end
      end

      def disable_lazy_transactions!
        materialize_transactions
        @lazy_transactions_enabled = false
      end

      def enable_lazy_transactions!
        @lazy_transactions_enabled = true
      end

      def lazy_transactions_enabled?
        @lazy_transactions_enabled
      end

      def materialize_transactions
        return if @materializing_transactions
        return unless @has_unmaterialized_transactions

        @connection.lock.synchronize do
          begin
            @materializing_transactions = true
            @stack.each { |t| t.materialize! unless t.materialized? }
          ensure
            @materializing_transactions = false
          end
          @has_unmaterialized_transactions = false
        end
      end

      def commit_transaction
        @connection.lock.synchronize do
          transaction = @stack.last

          begin
            transaction.before_commit_records
          ensure
            @stack.pop
          end

          transaction.commit
          transaction.commit_records
        end
      end

      def rollback_transaction(transaction = nil)
        @connection.lock.synchronize do
          transaction ||= @stack.pop
          transaction.rollback
          transaction.rollback_records
        end
      end

      def within_new_transaction(options = {})
        @connection.lock.synchronize do
          begin
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
                  commit_transaction if transaction
                rescue Exception
                  rollback_transaction(transaction) unless transaction.state.completed?
                  raise
                end
              end
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
