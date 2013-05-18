require 'active_support/notifications'

module ActiveRecord
  class ExplainSubscriber # :nodoc:
    def call(*args)
      if queries = Thread.current[:available_queries_for_explain]
        payload = args.last
        queries << payload.values_at(:sql, :binds) unless ignore_payload?(payload)
      end
    end

    # SCHEMA queries cannot be EXPLAINed, also we do not want to run EXPLAIN on
    # our own EXPLAINs now matter how loopingly beautiful that would be.
    #
    # On the other hand, we want to monitor the performance of our real database
    # queries, not the performance of the access to the query cache.
    IGNORED_PAYLOADS = %w(SCHEMA EXPLAIN CACHE)
    EXPLAINED_SQLS = /\A\s*(select|update|delete|insert)\b/i
    def ignore_payload?(payload)
      payload[:exception] || IGNORED_PAYLOADS.include?(payload[:name]) || payload[:sql] !~ EXPLAINED_SQLS
    end

    ActiveSupport::Notifications.subscribe("sql.active_record", new)
  end
end
