require 'active_record/vendor/simple.rb'
require 'thread'

module ActiveRecord
  module Transactions # :nodoc:
    def self.append_features(base)
      super
      base.extend(ClassMethods)

      base.class_eval do
        alias_method :destroy_without_transactions, :destroy
        alias_method :destroy, :destroy_with_transactions
      end
    end

    # Transactions are protective blocks where SQL statements are only permanent if they can all succed as one atomic action. 
    # The classic example is a transfer between two accounts where you can only have a deposit if the withdrawal succedded and
    # vice versa. Transaction enforce the integrity of the database and guards the data against program errors or database break-downs.
    # So basically you should use transaction blocks whenever you have a number of statements that must be executed together or
    # not at all. Example:
    #
    #   Account.transaction do
    #     david.withdrawal(100)
    #     mary.deposit(100)
    #   end
    #
    # This example will only take money from David and give to Mary if neither +withdrawal+ nor +deposit+ raises an exception.
    # Exceptions will force a ROLLBACK that returns the database to the state before the transaction was begun. Be aware, though,
    # that the objects by default will _not_ have their instance data returned to their pre-transactional state.
    #
    # == Object-level transactions
    #
    # You can enable object-level transactions for Active Record objects, though. You do this by naming the each of the Active Records
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
      @@mutex = Mutex.new
    
      def transaction(*objects, &block)
        Thread.current['transaction_running'] ||= 0
        @@mutex.lock if Thread.current['transaction_running'] == 0

        begin
          objects.each { |o| o.extend(Transaction::Simple) }
          objects.each { |o| o.start_transaction }
          connection.begin_db_transaction if Thread.current['transaction_running'] == 0
          Thread.current['transaction_running'] += 1

          block.call
  
          Thread.current['transaction_running'] -= 1
          connection.commit_db_transaction if Thread.current['transaction_running'] == 0
          objects.each { |o| o.commit_transaction }
        rescue Exception => exception
          Thread.current['transaction_running'] -= 1
          connection.rollback_db_transaction if Thread.current['transaction_running'] == 0
          objects.each { |o| o.abort_transaction }
          raise exception
        ensure
          @@mutex.unlock
        end
      end
    end

    def destroy_with_transactions #:nodoc:
      ActiveRecord::Base.transaction do
        destroy_without_transactions
      end
    end
  end
end