# frozen_string_literal: true

module ActiveRecord
  # See ActiveRecord::Transactions::ClassMethods for documentation.
  module Transactions
    extend ActiveSupport::Concern
    #:nodoc:
    ACTIONS = [:create, :destroy, :update]

    included do
      define_callbacks :commit, :rollback,
                       :before_commit,
                       :before_commit_without_transaction_enrollment,
                       :commit_without_transaction_enrollment,
                       :rollback_without_transaction_enrollment,
                       scope: [:kind, :name]
    end

    # = Active Record Transactions
    #
    # \Transactions are protective blocks where SQL statements are only permanent
    # if they can all succeed as one atomic action. The classic example is a
    # transfer between two accounts where you can only have a deposit if the
    # withdrawal succeeded and vice versa. \Transactions enforce the integrity of
    # the database and guard the data against program errors or database
    # break-downs. So basically you should use transaction blocks whenever you
    # have a number of statements that must be executed together or not at all.
    #
    # For example:
    #
    #   ActiveRecord::Base.transaction do
    #     david.withdrawal(100)
    #     mary.deposit(100)
    #   end
    #
    # This example will only take money from David and give it to Mary if neither
    # +withdrawal+ nor +deposit+ raise an exception. Exceptions will force a
    # ROLLBACK that returns the database to the state before the transaction
    # began. Be aware, though, that the objects will _not_ have their instance
    # data returned to their pre-transactional state.
    #
    # == Different Active Record classes in a single transaction
    #
    # Though the #transaction class method is called on some Active Record class,
    # the objects within the transaction block need not all be instances of
    # that class. This is because transactions are per-database connection, not
    # per-model.
    #
    # In this example a +balance+ record is transactionally saved even
    # though #transaction is called on the +Account+ class:
    #
    #   Account.transaction do
    #     balance.save!
    #     account.save!
    #   end
    #
    # The #transaction method is also available as a model instance method.
    # For example, you can also do this:
    #
    #   balance.transaction do
    #     balance.save!
    #     account.save!
    #   end
    #
    # == Transactions are not distributed across database connections
    #
    # A transaction acts on a single database connection. If you have
    # multiple class-specific databases, the transaction will not protect
    # interaction among them. One workaround is to begin a transaction
    # on each class whose models you alter:
    #
    #   Student.transaction do
    #     Course.transaction do
    #       course.enroll(student)
    #       student.units += course.units
    #     end
    #   end
    #
    # This is a poor solution, but fully distributed transactions are beyond
    # the scope of Active Record.
    #
    # == +save+ and +destroy+ are automatically wrapped in a transaction
    #
    # Both {#save}[rdoc-ref:Persistence#save] and
    # {#destroy}[rdoc-ref:Persistence#destroy] come wrapped in a transaction that ensures
    # that whatever you do in validations or callbacks will happen under its
    # protected cover. So you can use validations to check for values that
    # the transaction depends on or you can raise exceptions in the callbacks
    # to rollback, including <tt>after_*</tt> callbacks.
    #
    # As a consequence changes to the database are not seen outside your connection
    # until the operation is complete. For example, if you try to update the index
    # of a search engine in +after_save+ the indexer won't see the updated record.
    # The #after_commit callback is the only one that is triggered once the update
    # is committed. See below.
    #
    # == Exception handling and rolling back
    #
    # Also have in mind that exceptions thrown within a transaction block will
    # be propagated (after triggering the ROLLBACK), so you should be ready to
    # catch those in your application code.
    #
    # One exception is the ActiveRecord::Rollback exception, which will trigger
    # a ROLLBACK when raised, but not be re-raised by the transaction block.
    #
    # *Warning*: one should not catch ActiveRecord::StatementInvalid exceptions
    # inside a transaction block. ActiveRecord::StatementInvalid exceptions indicate that an
    # error occurred at the database level, for example when a unique constraint
    # is violated. On some database systems, such as PostgreSQL, database errors
    # inside a transaction cause the entire transaction to become unusable
    # until it's restarted from the beginning. Here is an example which
    # demonstrates the problem:
    #
    #   # Suppose that we have a Number model with a unique column called 'i'.
    #   Number.transaction do
    #     Number.create(i: 0)
    #     begin
    #       # This will raise a unique constraint error...
    #       Number.create(i: 0)
    #     rescue ActiveRecord::StatementInvalid
    #       # ...which we ignore.
    #     end
    #
    #     # On PostgreSQL, the transaction is now unusable. The following
    #     # statement will cause a PostgreSQL error, even though the unique
    #     # constraint is no longer violated:
    #     Number.create(i: 1)
    #     # => "PG::Error: ERROR:  current transaction is aborted, commands
    #     #     ignored until end of transaction block"
    #   end
    #
    # One should restart the entire transaction if an
    # ActiveRecord::StatementInvalid occurred.
    #
    # == Nested transactions
    #
    # #transaction calls can be nested. By default, this makes all database
    # statements in the nested transaction block become part of the parent
    # transaction. For example, the following behavior may be surprising:
    #
    #   User.transaction do
    #     User.create(username: 'Kotori')
    #     User.transaction do
    #       User.create(username: 'Nemu')
    #       raise ActiveRecord::Rollback
    #     end
    #   end
    #
    # creates both "Kotori" and "Nemu". Reason is the ActiveRecord::Rollback
    # exception in the nested block does not issue a ROLLBACK. Since these exceptions
    # are captured in transaction blocks, the parent block does not see it and the
    # real transaction is committed.
    #
    # In order to get a ROLLBACK for the nested transaction you may ask for a real
    # sub-transaction by passing <tt>requires_new: true</tt>. If anything goes wrong,
    # the database rolls back to the beginning of the sub-transaction without rolling
    # back the parent transaction. If we add it to the previous example:
    #
    #   User.transaction do
    #     User.create(username: 'Kotori')
    #     User.transaction(requires_new: true) do
    #       User.create(username: 'Nemu')
    #       raise ActiveRecord::Rollback
    #     end
    #   end
    #
    # only "Kotori" is created. This works on MySQL and PostgreSQL. SQLite3 version >= '3.6.8' also supports it.
    #
    # Most databases don't support true nested transactions. At the time of
    # writing, the only database that we're aware of that supports true nested
    # transactions, is MS-SQL. Because of this, Active Record emulates nested
    # transactions by using savepoints on MySQL and PostgreSQL. See
    # https://dev.mysql.com/doc/refman/5.7/en/savepoint.html
    # for more information about savepoints.
    #
    # === \Callbacks
    #
    # There are two types of callbacks associated with committing and rolling back transactions:
    # #after_commit and #after_rollback.
    #
    # #after_commit callbacks are called on every record saved or destroyed within a
    # transaction immediately after the transaction is committed. #after_rollback callbacks
    # are called on every record saved or destroyed within a transaction immediately after the
    # transaction or savepoint is rolled back.
    #
    # These callbacks are useful for interacting with other systems since you will be guaranteed
    # that the callback is only executed when the database is in a permanent state. For example,
    # #after_commit is a good spot to put in a hook to clearing a cache since clearing it from
    # within a transaction could trigger the cache to be regenerated before the database is updated.
    #
    # === Caveats
    #
    # If you're on MySQL, then do not use Data Definition Language (DDL) operations in nested
    # transactions blocks that are emulated with savepoints. That is, do not execute statements
    # like 'CREATE TABLE' inside such blocks. This is because MySQL automatically
    # releases all savepoints upon executing a DDL operation. When +transaction+
    # is finished and tries to release the savepoint it created earlier, a
    # database error will occur because the savepoint has already been
    # automatically released. The following example demonstrates the problem:
    #
    #   Model.connection.transaction do                           # BEGIN
    #     Model.connection.transaction(requires_new: true) do     # CREATE SAVEPOINT active_record_1
    #       Model.connection.create_table(...)                    # active_record_1 now automatically released
    #     end                                                     # RELEASE SAVEPOINT active_record_1
    #                                                             # ^^^^ BOOM! database error!
    #   end
    #
    # Note that "TRUNCATE" is also a MySQL DDL statement!
    module ClassMethods
      # See the ConnectionAdapters::DatabaseStatements#transaction API docs.
      def transaction(options = {}, &block)
        connection.transaction(options, &block)
      end

      def before_commit(*args, &block) # :nodoc:
        set_options_for_callbacks!(args)
        set_callback(:before_commit, :before, *args, &block)
      end

      # This callback is called after a record has been created, updated, or destroyed.
      #
      # You can specify that the callback should only be fired by a certain action with
      # the +:on+ option:
      #
      #   after_commit :do_foo, on: :create
      #   after_commit :do_bar, on: :update
      #   after_commit :do_baz, on: :destroy
      #
      #   after_commit :do_foo_bar, on: [:create, :update]
      #   after_commit :do_bar_baz, on: [:update, :destroy]
      #
      def after_commit(*args, &block)
        set_options_for_callbacks!(args)
        set_callback(:commit, :after, *args, &block)
      end

      # Shortcut for <tt>after_commit :hook, on: :create</tt>.
      def after_create_commit(*args, &block)
        set_options_for_callbacks!(args, on: :create)
        set_callback(:commit, :after, *args, &block)
      end

      # Shortcut for <tt>after_commit :hook, on: :update</tt>.
      def after_update_commit(*args, &block)
        set_options_for_callbacks!(args, on: :update)
        set_callback(:commit, :after, *args, &block)
      end

      # Shortcut for <tt>after_commit :hook, on: :destroy</tt>.
      def after_destroy_commit(*args, &block)
        set_options_for_callbacks!(args, on: :destroy)
        set_callback(:commit, :after, *args, &block)
      end

      # This callback is called after a create, update, or destroy are rolled back.
      #
      # Please check the documentation of #after_commit for options.
      def after_rollback(*args, &block)
        set_options_for_callbacks!(args)
        set_callback(:rollback, :after, *args, &block)
      end

      def before_commit_without_transaction_enrollment(*args, &block) # :nodoc:
        set_options_for_callbacks!(args)
        set_callback(:before_commit_without_transaction_enrollment, :before, *args, &block)
      end

      def after_commit_without_transaction_enrollment(*args, &block) # :nodoc:
        set_options_for_callbacks!(args)
        set_callback(:commit_without_transaction_enrollment, :after, *args, &block)
      end

      def after_rollback_without_transaction_enrollment(*args, &block) # :nodoc:
        set_options_for_callbacks!(args)
        set_callback(:rollback_without_transaction_enrollment, :after, *args, &block)
      end

      private

        def set_options_for_callbacks!(args, enforced_options = {})
          options = args.extract_options!.merge!(enforced_options)
          args << options

          if options[:on]
            fire_on = Array(options[:on])
            assert_valid_transaction_action(fire_on)
            options[:if] = Array(options[:if])
            options[:if].unshift(-> { transaction_include_any_action?(fire_on) })
          end
        end

        def assert_valid_transaction_action(actions)
          if (actions - ACTIONS).any?
            raise ArgumentError, ":on conditions for after_commit and after_rollback callbacks have to be one of #{ACTIONS}"
          end
        end
    end

    # See ActiveRecord::Transactions::ClassMethods for detailed documentation.
    def transaction(options = {}, &block)
      self.class.transaction(options, &block)
    end

    def destroy #:nodoc:
      raise RecordAlreadyDestroyed.new("Record is already destroyed", self) if destroyed?
      with_transaction_returning_status { super }
    end

    def save(*) #:nodoc:
      rollback_active_record_state! do
        with_transaction_returning_status { super }
      end
    end

    def save!(*) #:nodoc:
      with_transaction_returning_status { super }
    end

    def touch(*) #:nodoc:
      with_transaction_returning_status { super }
    end

    # Reset id and @new_record if the transaction rolls back.
    def rollback_active_record_state!
      remember_transaction_record_state
      yield
    rescue Exception
      restore_transaction_record_state
      raise
    ensure
      clear_transaction_record_state
    end

    def before_committed! # :nodoc:
      _run_before_commit_without_transaction_enrollment_callbacks
      _run_before_commit_callbacks
    end

    # Call the #after_commit callbacks.
    #
    # Ensure that it is not called if the object was never persisted (failed create),
    # but call it after the commit of a destroyed object.
    def committed!(should_run_callbacks: true) #:nodoc:
      if should_run_callbacks && destroyed? || persisted?
        _run_commit_without_transaction_enrollment_callbacks
        _run_commit_callbacks
      end
    ensure
      force_clear_transaction_record_state
    end

    # Call the #after_rollback callbacks. The +force_restore_state+ argument indicates if the record
    # state should be rolled back to the beginning or just to the last savepoint.
    def rolledback!(force_restore_state: false, should_run_callbacks: true) #:nodoc:
      if should_run_callbacks
        _run_rollback_callbacks
        _run_rollback_without_transaction_enrollment_callbacks
      end
    ensure
      restore_transaction_record_state(force_restore_state)
      clear_transaction_record_state
    end

    # Add the record to the current transaction so that the #after_rollback and #after_commit callbacks
    # can be called.
    def add_to_transaction
      if has_transactional_callbacks?
        self.class.connection.add_transaction_record(self)
      else
        sync_with_transaction_state
        set_transaction_state(self.class.connection.transaction_state)
      end
      remember_transaction_record_state
    end

    # Executes +method+ within a transaction and captures its return value as a
    # status flag. If the status is true the transaction is committed, otherwise
    # a ROLLBACK is issued. In any case the status flag is returned.
    #
    # This method is available within the context of an ActiveRecord::Base
    # instance.
    def with_transaction_returning_status
      status = nil
      self.class.transaction do
        add_to_transaction
        begin
          status = yield
        rescue ActiveRecord::Rollback
          clear_transaction_record_state
          status = nil
        end

        raise ActiveRecord::Rollback unless status
      end
      status
    ensure
      if @transaction_state && @transaction_state.committed?
        clear_transaction_record_state
      end
    end

    private

      # Save the new record state and id of a record so it can be restored later if a transaction fails.
      def remember_transaction_record_state
        @_start_transaction_state[:id] = id
        @_start_transaction_state.reverse_merge!(
          new_record: @new_record,
          destroyed: @destroyed,
          frozen?: frozen?,
        )
        @_start_transaction_state[:level] = (@_start_transaction_state[:level] || 0) + 1
      end

      # Clear the new record state and id of a record.
      def clear_transaction_record_state
        @_start_transaction_state[:level] = (@_start_transaction_state[:level] || 0) - 1
        force_clear_transaction_record_state if @_start_transaction_state[:level] < 1
      end

      # Force to clear the transaction record state.
      def force_clear_transaction_record_state
        @_start_transaction_state.clear
      end

      # Restore the new record state and id of a record that was previously saved by a call to save_record_state.
      def restore_transaction_record_state(force = false)
        unless @_start_transaction_state.empty?
          transaction_level = (@_start_transaction_state[:level] || 0) - 1
          if transaction_level < 1 || force
            restore_state = @_start_transaction_state
            thaw
            @new_record = restore_state[:new_record]
            @destroyed  = restore_state[:destroyed]
            pk = self.class.primary_key
            if pk && _read_attribute(pk) != restore_state[:id]
              _write_attribute(pk, restore_state[:id])
            end
            freeze if restore_state[:frozen?]
          end
        end
      end

      # Determine if a record was created or destroyed in a transaction. State should be one of :new_record or :destroyed.
      def transaction_record_state(state)
        @_start_transaction_state[state]
      end

      # Determine if a transaction included an action for :create, :update, or :destroy. Used in filtering callbacks.
      def transaction_include_any_action?(actions)
        actions.any? do |action|
          case action
          when :create
            transaction_record_state(:new_record)
          when :destroy
            defined?(@_trigger_destroy_callback) && @_trigger_destroy_callback
          when :update
            !(transaction_record_state(:new_record) || destroyed?) &&
              (defined?(@_trigger_update_callback) && @_trigger_update_callback)
          end
        end
      end

      def set_transaction_state(state)
        @transaction_state = state
      end

      def has_transactional_callbacks?
        !_rollback_callbacks.empty? || !_commit_callbacks.empty? || !_before_commit_callbacks.empty?
      end

      # Updates the attributes on this particular Active Record object so that
      # if it's associated with a transaction, then the state of the Active Record
      # object will be updated to reflect the current state of the transaction.
      #
      # The <tt>@transaction_state</tt> variable stores the states of the associated
      # transaction. This relies on the fact that a transaction can only be in
      # one rollback or commit (otherwise a list of states would be required).
      # Each Active Record object inside of a transaction carries that transaction's
      # TransactionState.
      #
      # This method checks to see if the ActiveRecord object's state reflects
      # the TransactionState, and rolls back or commits the Active Record object
      # as appropriate.
      #
      # Since Active Record objects can be inside multiple transactions, this
      # method recursively goes through the parent of the TransactionState and
      # checks if the Active Record object reflects the state of the object.
      def sync_with_transaction_state
        update_attributes_from_transaction_state(@transaction_state)
      end

      def update_attributes_from_transaction_state(transaction_state)
        if transaction_state && transaction_state.finalized?
          restore_transaction_record_state if transaction_state.rolledback?
          clear_transaction_record_state if transaction_state.fully_completed?
        end
      end
  end
end
