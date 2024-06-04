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
  # won't be rolled back. Relying solely on these to synchronize state between multiple systems may lead to consistency issues.
  class Transaction
    COMMITTED_TRANSACTION = ActiveRecord::ConnectionAdapters::NullTransaction.new(true).freeze
    ABORTED_TRANSACTION = ActiveRecord::ConnectionAdapters::NullTransaction.new(false).freeze

    def initialize(internal_transaction) # :nodoc:
      @internal_transaction = internal_transaction
      @uuid = nil
    end

    NULL_TRANSACTION = new(nil).freeze

    delegate :open?, :closed?, :before_commit, :after_commit, :after_rollback, to: :target

    def blank?
      @internal_transaction.nil?
    end

    # Returns a UUID for this transaction.
    def uuid
      if @internal_transaction
        @uuid ||= Digest::UUID.uuid_v4
      end
    end

    private
      def target
        if @internal_transaction.nil? || @internal_transaction.fully_committed?
          COMMITTED_TRANSACTION
        elsif @internal_transaction.rolledback?
          ABORTED_TRANSACTION
        else
          @internal_transaction
        end
      end
  end
end
