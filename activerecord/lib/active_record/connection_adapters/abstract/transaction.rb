# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    # = Active Record Connection Adapters Transaction State
    class TransactionState
      def initialize(state = nil)
        @state = state
        @children = nil
      end

      def add_child(state)
        @children ||= []
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

      def invalidated?
        @state == :invalidated
      end

      def fully_completed?
        completed?
      end

      def completed?
        committed? || rolledback?
      end

      def rollback!
        @children&.each { |c| c.rollback! }
        @state = :rolledback
      end

      def full_rollback!
        @children&.each { |c| c.rollback! }
        @state = :fully_rolledback
      end

      def invalidate!
        @children&.each { |c| c.invalidate! }
        @state = :invalidated
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

    class NullTransaction # :nodoc:
      def initialize; end
      def state; end
      def closed?; true; end
      def open?; false; end
      def joinable?; false; end
      def add_record(record, _ = true); end
      def restartable?; false; end
      def dirty?; false; end
      def dirty!; end
      def invalidated?; false; end
      def invalidate!; end
    end

    class Transaction # :nodoc:
      attr_reader :connection, :state, :savepoint_name, :isolation_level
      attr_accessor :written, :written_indirectly

      delegate :invalidate!, :invalidated?, to: :@state

      def initialize(connection, isolation: nil, joinable: true, run_commit_callbacks: false)
        @connection = connection
        @state = TransactionState.new
        @records = nil
        @isolation_level = isolation
        @materialized = false
        @joinable = joinable
        @run_commit_callbacks = run_commit_callbacks
        @lazy_enrollment_records = nil
        @dirty = false
      end

      def dirty!
        @dirty = true
      end

      def dirty?
        @dirty
      end

      def add_record(record, ensure_finalize = true)
        @records ||= []
        if ensure_finalize
          @records << record
        else
          @lazy_enrollment_records ||= ObjectSpace::WeakMap.new
          @lazy_enrollment_records[record] = record
        end
      end

      def records
        if @lazy_enrollment_records
          @records.concat @lazy_enrollment_records.values
          @lazy_enrollment_records = nil
        end
        @records
      end

      # Can this transaction's current state be recreated by
      # rollback+begin ?
      def restartable?
        joinable? && !dirty?
      end

      def materialize!
        @materialized = true
      end

      def materialized?
        @materialized
      end

      def restore!
        if materialized?
          @materialized = false
          materialize!
        end
      end

      def rollback_records
        return unless records

        ite = unique_records

        instances_to_run_callbacks_on = prepare_instances_to_run_callbacks_on(ite)

        run_action_on_records(ite, instances_to_run_callbacks_on) do |record, should_run_callbacks|
          record.rolledback!(force_restore_state: full_rollback?, should_run_callbacks: should_run_callbacks)
        end
      ensure
        ite&.each do |i|
          i.rolledback!(force_restore_state: full_rollback?, should_run_callbacks: false)
        end
      end

      def before_commit_records
        return unless records

        if @run_commit_callbacks
          if ActiveRecord.before_committed_on_all_records
            ite = unique_records

            instances_to_run_callbacks_on = records.each_with_object({}) do |record, candidates|
              candidates[record] = record
            end

            run_action_on_records(ite, instances_to_run_callbacks_on) do |record, should_run_callbacks|
              record.before_committed! if should_run_callbacks
            end
          else
            records.uniq.each(&:before_committed!)
          end
        end
      end

      def commit_records
        return unless records

        ite = unique_records

        if @run_commit_callbacks
          instances_to_run_callbacks_on = prepare_instances_to_run_callbacks_on(ite)

          run_action_on_records(ite, instances_to_run_callbacks_on) do |record, should_run_callbacks|
            record.committed!(should_run_callbacks: should_run_callbacks)
          end
        else
          while record = ite.shift
            # if not running callbacks, only adds the record to the parent transaction
            connection.add_transaction_record(record)
          end
        end
      ensure
        ite&.each { |i| i.committed!(should_run_callbacks: false) }
      end

      def full_rollback?; true; end
      def joinable?; @joinable; end
      def closed?; false; end
      def open?; !closed?; end

      private
        def unique_records
          records.uniq(&:__id__)
        end

        def run_action_on_records(records, instances_to_run_callbacks_on)
          while record = records.shift
            should_run_callbacks = record.__id__ == instances_to_run_callbacks_on[record].__id__

            yield record, should_run_callbacks
          end
        end

        def prepare_instances_to_run_callbacks_on(records)
          records.each_with_object({}) do |record, candidates|
            next unless record.trigger_transactional_callbacks?

            earlier_saved_candidate = candidates[record]

            next if earlier_saved_candidate && record.class.run_commit_callbacks_on_first_saved_instances_in_transaction

            # If the candidate instance destroyed itself in the database, then
            # instances which were added to the transaction afterwards, and which
            # think they updated themselves, are wrong. They should not replace
            # our candidate as an instance to run callbacks on
            next if earlier_saved_candidate&.destroyed? && !record.destroyed?

            # If the candidate instance was created inside of this transaction,
            # then instances which were subsequently loaded from the database
            # and updated need that state transferred to them so that
            # the after_create_commit callbacks are run
            record._new_record_before_last_commit = true if earlier_saved_candidate&._new_record_before_last_commit

            # The last instance to save itself is likeliest to have internal
            # state that matches what's committed to the database
            candidates[record] = record
          end
        end
    end

    # = Active Record Restart Parent \Transaction
    class RestartParentTransaction < Transaction
      def initialize(connection, parent_transaction, **options)
        super(connection, **options)

        @parent = parent_transaction

        if isolation_level
          raise ActiveRecord::TransactionIsolationError, "cannot set transaction isolation in a nested transaction"
        end

        @parent.state.add_child(@state)
      end

      delegate :materialize!, :materialized?, :restart, to: :@parent

      def rollback
        @state.rollback!
        @parent.restart
      end

      def commit
        @state.commit!
      end

      def full_rollback?; false; end
    end

    # = Active Record Savepoint \Transaction
    class SavepointTransaction < Transaction
      def initialize(connection, savepoint_name, parent_transaction, **options)
        super(connection, **options)

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

      def restart
        connection.rollback_to_savepoint(savepoint_name) if materialized?
      end

      def rollback
        unless @state.invalidated?
          connection.rollback_to_savepoint(savepoint_name) if materialized?
        end
        @state.rollback!
      end

      def commit
        connection.release_savepoint(savepoint_name) if materialized?
        @state.commit!
      end

      def full_rollback?; false; end
    end

    # = Active Record Real \Transaction
    class RealTransaction < Transaction
      def materialize!
        if isolation_level
          connection.begin_isolated_db_transaction(isolation_level)
        else
          connection.begin_db_transaction
        end

        super
      end

      def restart
        return unless materialized?

        if connection.supports_restart_db_transaction?
          connection.restart_db_transaction
        else
          connection.rollback_db_transaction
          materialize!
        end
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

    class TransactionManager # :nodoc:
      def initialize(connection)
        @stack = []
        @connection = connection
        @has_unmaterialized_transactions = false
        @materializing_transactions = false
        @lazy_transactions_enabled = true
      end

      def begin_transaction(isolation: nil, joinable: true, _lazy: true)
        @connection.lock.synchronize do
          run_commit_callbacks = !current_transaction.joinable?
          transaction =
            if @stack.empty?
              RealTransaction.new(
                @connection,
                isolation: isolation,
                joinable: joinable,
                run_commit_callbacks: run_commit_callbacks
              )
            elsif current_transaction.restartable?
              RestartParentTransaction.new(
                @connection,
                current_transaction,
                isolation: isolation,
                joinable: joinable,
                run_commit_callbacks: run_commit_callbacks
              )
            else
              SavepointTransaction.new(
                @connection,
                "active_record_#{@stack.size}",
                current_transaction,
                isolation: isolation,
                joinable: joinable,
                run_commit_callbacks: run_commit_callbacks
              )
            end

          unless transaction.materialized?
            if @connection.supports_lazy_transactions? && lazy_transactions_enabled? && _lazy
              @has_unmaterialized_transactions = true
            else
              transaction.materialize!
            end
          end
          @stack.push(transaction)
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

      def dirty_current_transaction
        current_transaction.dirty!
      end

      def restore_transactions
        return false unless restorable?

        @stack.each(&:restore!)

        true
      end

      def restorable?
        @stack.none?(&:dirty?)
      end

      def materialize_transactions
        return if @materializing_transactions

        if @has_unmaterialized_transactions
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
      end

      def commit_transaction
        @connection.lock.synchronize do
          transaction = @stack.last

          begin
            transaction.before_commit_records
          ensure
            @stack.pop
          end

          dirty_current_transaction if transaction.dirty?

          if current_transaction.open?
            current_transaction.written_indirectly ||= transaction.written || transaction.written_indirectly
          end

          transaction.commit
          transaction.commit_records
        end
      end

      def rollback_transaction(transaction = nil)
        @connection.lock.synchronize do
          transaction ||= @stack.last
          begin
            transaction.rollback
          ensure
            @stack.pop if @stack.last == transaction
          end
          transaction.rollback_records
        end
      end

      def within_new_transaction(isolation: nil, joinable: true)
        @connection.lock.synchronize do
          transaction = begin_transaction(isolation: isolation, joinable: joinable)
          ret = yield
          completed = true
          ret
        rescue Exception => error
          if transaction
            rollback_transaction
            after_failure_actions(transaction, error)
          end

          raise
        ensure
          if transaction
            if error
              # @connection still holds an open or invalid transaction, so we must not
              # put it back in the pool for reuse.
              @connection.throw_away! unless transaction.state.rolledback?
            else
              if Thread.current.status == "aborting"
                rollback_transaction
              elsif !completed && transaction.written
                # This was deprecated in 6.1, and has now changed to a rollback
                rollback_transaction
              elsif !completed && !transaction.written_indirectly
                # This was a silent commit in 6.1, but now becomes a rollback; we skipped
                # the warning because (having not been written) the change generally won't
                # have any effect
                rollback_transaction
              else
                if !completed && transaction.written_indirectly
                  # This is the case that was missed in the 6.1 deprecation, so we have to
                  # do it now
                  ActiveRecord.deprecator.warn(<<~EOW)
                    Using `return`, `break` or `throw` to exit a transaction block is
                    deprecated without replacement. If the `throw` came from
                    `Timeout.timeout(duration)`, pass an exception class as a second
                    argument so it doesn't use `throw` to abort its block. This results
                    in the transaction being committed, but in the next release of Rails
                    it will rollback.
                  EOW
                end

                begin
                  commit_transaction
                rescue ActiveRecord::ConnectionFailed
                  transaction.invalidate! unless transaction.state.completed?
                  raise
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
