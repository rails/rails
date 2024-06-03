# frozen_string_literal: true

require "active_support/core_ext/digest"

module ActiveRecord
  # This abstract class specifies the interface to interact with the current transaction state.
  #
  # Any other methods not specified here are considered to be private interfaces.
  #
  # == Callbacks
  #
  # After updating the database state, you may sometimes need to perform some extra work, or reflect these
  # changes in a remote system like clearing or updating a cache:
  #
  # def publish_article(article)
  #   article.update!(published: true)
  #   NotificationService.article_published(article)
  # end
  #
  # The above code works but has one important flaw, which is that it no longer works properly if called inside
  # a transaction, as it will interact with the remote system before the changes are persisted:
  #
  # Article.transaction do
  #   article = create_article(article)
  #   publish_article(article)
  # end
  #
  # The callbacks offered by ActiveRecord::Transaction allow to rewriting this method in a way that is compatible
  # with transactions:
  #
  # def publish_article(article)
  #   article.update!(published: true)
  #   Article.current_transaction.after_commit do
  #     NotificationService.article_published(article)
  #   end
  # end
  #
  # In the above example, if +publish_article+ is called inside a transaction, the callback will be invoked
  # after the transaction is successfully committed, and if called outside a transaction, the callback will be invoked
  # immediately.
  #
  # == Caveats
  #
  # When using after_commit callbacks, it is important to note that if the callback raises an error, the transaction
  # won't be rolled back. Relying solely on these to synchronize state between multiple systems may lead to consistency issues.
  class Transaction
    class Callback # :nodoc:
      def initialize(event, callback)
        @event = event
        @callback = callback
      end

      def before_commit
        @callback.call if @event == :before_commit
      end

      def after_commit
        @callback.call if @event == :after_commit
      end

      def after_rollback
        @callback.call if @event == :after_rollback
      end
    end

    def initialize # :nodoc:
      @callbacks = nil
      @uuid = nil
    end

    # Registers a block to be called before the current transaction is fully committed.
    #
    # If there is no currently open transactions, the block is called immediately.
    #
    # If the current transaction has a parent transaction, the callback is transferred to
    # the parent when the current transaction commits, or dropped when the current transaction
    # is rolled back. This operation is repeated until the outermost transaction is reached.
    #
    # If the callback raises an error, the transaction is rolled back.
    def before_commit(&block)
      (@callbacks ||= []) << Callback.new(:before_commit, block)
    end

    # Registers a block to be called after the current transaction is fully committed.
    #
    # If there is no currently open transactions, the block is called immediately.
    #
    # If the current transaction has a parent transaction, the callback is transferred to
    # the parent when the current transaction commits, or dropped when the current transaction
    # is rolled back. This operation is repeated until the outermost transaction is reached.
    #
    # If the callback raises an error, the transaction remains committed.
    def after_commit(&block)
      (@callbacks ||= []) << Callback.new(:after_commit, block)
    end

    # Registers a block to be called after the current transaction is rolled back.
    #
    # If there is no currently open transactions, the block is never called.
    #
    # If the current transaction is successfully committed but has a parent
    # transaction, the callback is automatically added to the parent transaction.
    #
    # If the entire chain of nested transactions are all successfully committed,
    # the block is never called.
    def after_rollback(&block)
      (@callbacks ||= []) << Callback.new(:after_rollback, block)
    end

    # Returns true if a transaction was started.
    def open?
      true
    end

    # Returns true if no transaction is currently active.
    def closed?
      false
    end
    alias_method :blank?, :closed?

    # Returns a UUID for this transaction.
    def uuid
      @uuid ||= Digest::UUID.uuid_v4
    end

    protected
      def append_callbacks(callbacks) # :nodoc:
        (@callbacks ||= []).concat(callbacks)
      end
  end
end
