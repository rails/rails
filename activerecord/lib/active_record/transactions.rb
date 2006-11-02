require 'active_record/vendor/simple.rb'
Transaction::Simple.send(:remove_method, :transaction)
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
    # == Object-level transactions (deprecated)
    #
    # You can enable object-level transactions for Active Record objects, though. You do this by naming each of the Active Records
    # that you want to enable object-level transactions for, like this:
    #
    #   Account.transaction(david, mary) do
    #     david.withdrawal(100)
    #     mary.deposit(100)
    #   end
    #
    # If the transaction fails, David and Mary will be returned to their
    # pre-transactional state. No money will have changed hands in neither
    # object nor database.
    #
    # However, useful state such as validation errors are also rolled back,
    # limiting the usefulness of this feature. As such it is deprecated in
    # Rails 1.2 and will be removed in the next release. Install the
    # object_transactions plugin if you wish to continue using it.
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
        increment_open_transactions

        begin
          unless objects.empty?
            ActiveSupport::Deprecation.warn "Object transactions are deprecated and will be removed from Rails 2.0.  See http://www.rubyonrails.org/deprecation for details.", caller
            objects.each { |o| o.extend(Transaction::Simple) }
            objects.each { |o| o.start_transaction }
          end

          result = connection.transaction(Thread.current['start_db_transaction'], &block)

          objects.each { |o| o.commit_transaction }
          return result
        rescue Exception => object_transaction_rollback
          objects.each { |o| o.abort_transaction }
          raise
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

    def transaction(*objects, &block)
      self.class.transaction(*objects, &block)
    end

    def destroy_with_transactions #:nodoc:
      transaction { destroy_without_transactions }
    end

    def save_with_transactions(perform_validation = true) #:nodoc:
      transaction { save_without_transactions(perform_validation) }
    end

    def save_with_transactions! #:nodoc:
      transaction { save_without_transactions! }
    end
  end
end
