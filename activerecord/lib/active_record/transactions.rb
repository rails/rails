require 'active_record/vendor/simple.rb'
Transaction::Simple.send(:remove_method, :transaction)
require 'thread'

module ActiveRecord
  module Transactions # :nodoc:
    TRANSACTION_MUTEX = Mutex.new

    class TransactionError < ActiveRecordError # :nodoc:
    end

    def self.append_features(base)
      super
      base.extend(ClassMethods)

      base.class_eval do
        alias_method :destroy_without_transactions, :destroy
        alias_method :destroy, :destroy_with_transactions

        alias_method :save_without_transactions, :save
        alias_method :save, :save_with_transactions
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
    # depend on or you can raise exceptions in the callbacks to rollback.
    #
    # == Object-level transactions
    #
    # You can enable object-level transactions for Active Record objects, though. You do this by naming each of the Active Records
    # that you want to enable object-level transactions for, like this:
    #
    #   Account.transaction(david, mary) do
    #     david.withdrawal(100)
    #     mary.deposit(100)
    #   end
    #
    # If the transaction fails, David and Mary will be returned to their pre-transactional state. No money will have changed hands in
    # neither object nor database.
    #
    # == Exception handling
    #
    # Also have in mind that exceptions thrown within a transaction block will be propagated (after triggering the ROLLBACK), so you
    # should be ready to catch those in your application code.
    #
    # Tribute: Object-level transactions are implemented by Transaction::Simple by Austin Ziegler.
    module ClassMethods
      def transaction(*objects, &block)
        previous_handler = trap('TERM') { raise TransactionError, "Transaction aborted" }
        lock_mutex
        
        begin
          objects.each { |o| o.extend(Transaction::Simple) }
          objects.each { |o| o.start_transaction }

          result = connection.transaction(Thread.current['start_db_transaction'], &block)

          objects.each { |o| o.commit_transaction }
          return result
        rescue Exception => object_transaction_rollback
          objects.each { |o| o.abort_transaction }
          raise
        ensure
          unlock_mutex
          trap('TERM', previous_handler)
        end
      end
      
      def lock_mutex#:nodoc:
        Thread.current['open_transactions'] ||= 0
        TRANSACTION_MUTEX.lock if Thread.current['open_transactions'] == 0
        Thread.current['start_db_transaction'] = (Thread.current['open_transactions'] == 0)
        Thread.current['open_transactions'] += 1
      end
      
      def unlock_mutex#:nodoc:
        Thread.current['open_transactions'] -= 1
        TRANSACTION_MUTEX.unlock if Thread.current['open_transactions'] == 0
      end
    end

    def transaction(*objects, &block)
      self.class.transaction(*objects, &block)
    end

    def destroy_with_transactions #:nodoc:
      transaction { destroy_without_transactions }
    end
    
    def save_with_transactions(perform_validation = true) #:nodoc:
      transaction { save_without_transactions(perform_validation) }
    end
  end
end
