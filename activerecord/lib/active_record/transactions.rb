require 'thread'

module ActiveRecord
  module Transactions # :nodoc:
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

    # Transactions are protective blocks where SQL statements are only permanent if they can all succeed as one atomic action. 
    # The classic example is a transfer between two accounts where you can only have a deposit if the withdrawal succeeded and
    # vice versa. Transactions enforce the integrity of the database and guard the data against program errors or database break-downs.
    # So basically you should use transaction blocks whenever you have a number of statements that must be executed together or
    # not at all. Example:
    #
    #   transaction do
    #     david.withdrawal(100)
    #     mary.deposit(100)
    #   end
    #
    # This example will only take money from David and give to Mary if neither +withdrawal+ nor +deposit+ raises an exception.
    # Exceptions will force a ROLLBACK that returns the database to the state before the transaction was begun. Be aware, though,
    # that the objects by default will _not_ have their instance data returned to their pre-transactional state.
    #
    # == Different ActiveRecord classes in a single transaction
    #
    # Though the transaction class method is called on some ActiveRecord class,
    # the objects within the transaction block need not all be instances of
    # that class.
    # In this example a <tt>Balance</tt> record is transactionally saved even
    # though <tt>transaction</tt> is called on the <tt>Account</tt> class:
    #
    #   Account.transaction do
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
    # Both Base#save and Base#destroy come wrapped in a transaction that ensures that whatever you do in validations or callbacks
    # will happen under the protected cover of a transaction. So you can use validations to check for values that the transaction
    # depends on or you can raise exceptions in the callbacks to rollback.
    #
    # == Exception handling
    #
    # Also have in mind that exceptions thrown within a transaction block will be propagated (after triggering the ROLLBACK), so you
    # should be ready to catch those in your application code. One exception is the ActiveRecord::Rollback exception, which will
    # trigger a ROLLBACK when raised, but not be re-raised by the transaction block.
    module ClassMethods
      def transaction(&block)
        previous_handler = trap('TERM') { raise TransactionError, "Transaction aborted" }
        increment_open_transactions

        begin
          connection.transaction(Thread.current['start_db_transaction'], &block)
        ensure
          decrement_open_transactions
          trap('TERM', previous_handler)
        end
      end

      private
        def increment_open_transactions #:nodoc:
          open = Thread.current['open_transactions'] ||= 0
          Thread.current['start_db_transaction'] = open.zero?
          Thread.current['open_transactions'] = open + 1
        end

        def decrement_open_transactions #:nodoc:
          Thread.current['open_transactions'] -= 1
        end
    end

    def transaction(&block)
      self.class.transaction(&block)
    end

    def destroy_with_transactions #:nodoc:
      transaction { destroy_without_transactions }
    end

    def save_with_transactions(perform_validation = true) #:nodoc:
      rollback_active_record_state! { transaction { save_without_transactions(perform_validation) } }
    end

    def save_with_transactions! #:nodoc:
      rollback_active_record_state! { transaction { save_without_transactions! } }
    end

    # Reset id and @new_record if the transaction rolls back.
    def rollback_active_record_state!
      id_present = has_attribute?(self.class.primary_key)
      previous_id = id
      previous_new_record = @new_record
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
  end
end
