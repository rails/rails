require 'thread'

module ActiveRecord
  # See ActiveRecord::Transactions::ClassMethods for documentation.
  module Transactions
    class TransactionError < ActiveRecordError # :nodoc:
    end

    def self.included(base)
      base.extend(ClassMethods)

      base.class_eval do
        [:destroy, :save, :save!].each do |method|
          alias_method_chain method, :transactions
        end
      end
    end

    # Transactions are protective blocks where SQL statements are only permanent
    # if they can all succeed as one atomic action. The classic example is a
    # transfer between two accounts where you can only have a deposit if the
    # withdrawal succeeded and vice versa. Transactions enforce the integrity of
    # the database and guard the data against program errors or database
    # break-downs. So basically you should use transaction blocks whenever you
    # have a number of statements that must be executed together or not at all.
    # Example:
    #
    #   ActiveRecord::Base.transaction do
    #     david.withdrawal(100)
    #     mary.deposit(100)
    #   end
    #
    # This example will only take money from David and give to Mary if neither
    # +withdrawal+ nor +deposit+ raises an exception. Exceptions will force a
    # ROLLBACK that returns the database to the state before the transaction was
    # begun. Be aware, though, that the objects will _not_ have their instance
    # data returned to their pre-transactional state.
    #
    # == Different Active Record classes in a single transaction
    #
    # Though the transaction class method is called on some Active Record class,
    # the objects within the transaction block need not all be instances of
    # that class. This is because transactions are per-database connection, not
    # per-model.
    #
    # In this example a <tt>Balance</tt> record is transactionally saved even
    # though <tt>transaction</tt> is called on the <tt>Account</tt> class:
    #
    #   Account.transaction do
    #     balance.save!
    #     account.save!
    #   end
    #
    # Note that the +transaction+ method is also available as a model instance
    # method. For example, you can also do this:
    #
    #   balance.transaction do
    #     balance.save!
    #     account.save!
    #   end
    #
    # == Transactions are not distributed across database connections
    #
    # A transaction acts on a single database connection.  If you have
    # multiple class-specific databases, the transaction will not protect
    # interaction among them.  One workaround is to begin a transaction
    # on each class whose models you alter:
    #
    #   Student.transaction do
    #     Course.transaction do
    #       course.enroll(student)
    #       student.units += course.units
    #     end
    #   end
    #
    # This is a poor solution, but full distributed transactions are beyond
    # the scope of Active Record.
    #
    # == Save and destroy are automatically wrapped in a transaction
    #
    # Both Base#save and Base#destroy come wrapped in a transaction that ensures
    # that whatever you do in validations or callbacks will happen under the
    # protected cover of a transaction. So you can use validations to check for
    # values that the transaction depends on or you can raise exceptions in the
    # callbacks to rollback, including <tt>after_*</tt> callbacks.
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
    # inside a transaction block. StatementInvalid exceptions indicate that an
    # error occurred at the database level, for example when a unique constraint
    # is violated. On some database systems, such as PostgreSQL, database errors
    # inside a transaction causes the entire transaction to become unusable
    # until it's restarted from the beginning. Here is an example which
    # demonstrates the problem:
    #
    #   # Suppose that we have a Number model with a unique column called 'i'.
    #   Number.transaction do
    #     Number.create(:i => 0)
    #     begin
    #       # This will raise a unique constraint error...
    #       Number.create(:i => 0)
    #     rescue ActiveRecord::StatementInvalid
    #       # ...which we ignore.
    #     end
    #     
    #     # On PostgreSQL, the transaction is now unusable. The following
    #     # statement will cause a PostgreSQL error, even though the unique
    #     # constraint is no longer violated:
    #     Number.create(:i => 1)
    #     # => "PGError: ERROR:  current transaction is aborted, commands
    #     #     ignored until end of transaction block"
    #   end
    #
    # One should restart the entire transaction if a StatementError occurred.
    module ClassMethods
      # See ActiveRecord::Transactions::ClassMethods for detailed documentation.
      def transaction(&block)
        connection.increment_open_transactions

        begin
          connection.transaction(connection.open_transactions == 1, &block)
        ensure
          connection.decrement_open_transactions
        end
      end
    end

    # See ActiveRecord::Transactions::ClassMethods for detailed documentation.
    def transaction(&block)
      self.class.transaction(&block)
    end

    def destroy_with_transactions #:nodoc:
      with_transaction_returning_status(:destroy_without_transactions)
    end

    def save_with_transactions(perform_validation = true) #:nodoc:
      rollback_active_record_state! { with_transaction_returning_status(:save_without_transactions, perform_validation) }
    end

    def save_with_transactions! #:nodoc:
      rollback_active_record_state! { transaction { save_without_transactions! } }
    end

    # Reset id and @new_record if the transaction rolls back.
    def rollback_active_record_state!
      id_present = has_attribute?(self.class.primary_key)
      previous_id = id
      previous_new_record = new_record?
      yield
    rescue Exception
      @new_record = previous_new_record
      if id_present
        self.id = previous_id
      else
        @attributes.delete(self.class.primary_key)
        @attributes_cache.delete(self.class.primary_key)
      end
      raise
    end

    # Executes +method+ within a transaction and captures its return value as a
    # status flag. If the status is true the transaction is committed, otherwise
    # a ROLLBACK is issued. In any case the status flag is returned.
    #
    # This method is available within the context of an ActiveRecord::Base
    # instance.
    def with_transaction_returning_status(method, *args)
      status = nil
      transaction do
        status = send(method, *args)
        raise ActiveRecord::Rollback unless status
      end
      status
    end
  end
end
