# frozen_string_literal: true

module ActiveRecord
  # This is a thread locals registry for Active Record. For example:
  #
  #   ActiveRecord::RuntimeRegistry.stats.sql_runtime
  #
  # returns the connection handler local to the current unit of execution (either thread of fiber).
  module RuntimeRegistry # :nodoc:
    class Stats
      attr_accessor :sql_runtime, :async_sql_runtime, :queries_count, :cached_queries_count

      def initialize
        @sql_runtime = 0.0
        @async_sql_runtime = 0.0
        @queries_count = 0
        @cached_queries_count = 0
      end

      def reset_runtimes
        sql_runtime_was = @sql_runtime
        @sql_runtime = 0.0
        @async_sql_runtime = 0.0
        sql_runtime_was
      end

      public alias_method :reset, :initialize
    end

    extend self

    def call(name, start, finish, id, payload)
      record(
        payload[:name],
        (finish - start) * 1_000.0,
        cached: payload[:cached],
        async: payload[:async],
        lock_wait: payload[:lock_wait],
      )
    end

    def record(query_name, runtime, cached: false, async: false, lock_wait: nil)
      stats = self.stats

      unless query_name == "TRANSACTION" || query_name == "SCHEMA"
        stats.queries_count += 1
        stats.cached_queries_count += 1 if cached
      end

      if async
        stats.async_sql_runtime += (runtime - lock_wait)
      end
      stats.sql_runtime += runtime
    end

    def stats
      ActiveSupport::IsolatedExecutionState[:active_record_runtime] ||= Stats.new
    end

    def reset
      stats.reset
    end
  end
end

ActiveSupport::Notifications.monotonic_subscribe("sql.active_record", ActiveRecord::RuntimeRegistry)
