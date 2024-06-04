# frozen_string_literal: true

require "active_support/core_ext/digest"

module ActiveRecord
  # Class specifies the interface to interact with the current transaction state.
  #
  # It can either map to an actual transaction or represent the abscence of a transaction.
  #
  # == State
  #
  # You can check whether a transaction is open with the +open?+ or +closed?+ methods
  #
  #  if Article.current_transaction.open?
  #    # We are inside a transaction
  #  end
  #
  # == Callbacks
  #
  # After updating the database state, you may sometimes need to perform some extra work, or reflect these
  # changes in a remote system like clearing or updating a cache:
  #
  #   def publish_article(article)
  #     article.update!(published: true)
  #     NotificationService.article_published(article)
  #   end
  #
  # The above code works but has one important flaw, which is that it no longer works properly if called inside
  # a transaction, as it will interact with the remote system before the changes are persisted:
  #
  #   Article.transaction do
  #     article = create_article(article)
  #     publish_article(article)
  #   end
  #
  # The callbacks offered by ActiveRecord::Transaction allow to rewriting this method in a way that is compatible
  # with transactions:
  #
  #   def publish_article(article)
  #     article.update!(published: true)
  #     Article.current_transaction.after_commit do
  #       NotificationService.article_published(article)
  #     end
  #   end
  #
  # In the above example, if +publish_article+ is called inside a transaction, the callback will be invoked
  # after the transaction is successfully committed, and if called outside a transaction, the callback will be invoked
  # immediately.
  #
  # == Caveats
  #
  # When using after_commit callbacks, it is important to note that if the callback raises an error, the transaction
  # won't be rolled back as it was already committed. Relying solely on these to synchronize state between multiple
  # systems may lead to consistency issues.
  class Transaction
    def initialize(internal_transaction) # :nodoc:
      @internal_transaction = internal_transaction
      @uuid = nil
    end

    # Registers a block to be called after the transaction is fully committed.
    #
    # If there is no currently open transactions, the block is called immediately.
    #
    # If the transaction has a parent transaction, the callback is transferred to
    # the parent when the current transaction commits, or dropped when the current transaction
    # is rolled back. This operation is repeated until the outermost transaction is reached.
    #
    # If the callback raises an error, the transaction remains committed.
    #
    # If the transaction is already finalized, attempting to register a callback
    # will raise ActiveRecord::ActiveRecordError
    def after_commit(&block)
      if @internal_transaction.nil?
        yield
      else
        @internal_transaction.after_commit(&block)
      end
    end

    # Registers a block to be called after the transaction is rolled back.
    #
    # If there is no currently open transactions, the block is never called.
    #
    # If the transaction is successfully committed but has a parent
    # transaction, the callback is automatically added to the parent transaction.
    #
    # If the entire chain of nested transactions are all successfully committed,
    # the block is never called.
    #
    # If the transaction is already finalized, attempting to register a callback
    # will raise ActiveRecord::ActiveRecordError
    def after_rollback(&block)
      @internal_transaction&.after_rollback(&block)
    end

    def open?
      @internal_transaction&.open?
    end

    def closed?
      !open?
    end

    alias_method :blank?, :closed?

    # Returns a UUID for this transaction or +nil+ if no transaction is open.
    def uuid
      if @internal_transaction
        @uuid ||= Digest::UUID.uuid_v4
      end
    end

    NULL_TRANSACTION = new(nil).freeze
  end
end
