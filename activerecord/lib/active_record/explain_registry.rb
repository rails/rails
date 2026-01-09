# frozen_string_literal: true


module ActiveRecord
  # This is a thread locals registry for EXPLAIN. For example
  #
  #   ActiveRecord::ExplainRegistry.queries
  #
  # returns the collected queries local to the current thread.
  class ExplainRegistry # :nodoc:
    class Subscriber
      MUTEX = Mutex.new
      @subscribed = false

      class << self
        def ensure_subscribed
          return if @subscribed
          MUTEX.synchronize do
            return if @subscribed

            ActiveSupport::Notifications.subscribe("sql.active_record", new)
            @subscribed = true
          end
        end
      end

      def start(name, id, payload)
        # unused
      end

      def finish(name, id, payload)
        if ExplainRegistry.collect? && !ignore_payload?(payload)
          ExplainRegistry.queries << payload.values_at(:sql, :binds)
        end
      end

      def silenced?(_name)
        !ExplainRegistry.collect?
      end

      # SCHEMA queries cannot be EXPLAINed, also we do not want to run EXPLAIN on
      # our own EXPLAINs no matter how loopingly beautiful that would be.
      #
      # On the other hand, we want to monitor the performance of our real database
      # queries, not the performance of the access to the query cache.
      IGNORED_PAYLOADS = %w(SCHEMA EXPLAIN)
      EXPLAINED_SQLS = /\A\s*(\/\*.*\*\/)?\s*(with|select|update|delete|insert)\b/i
      def ignore_payload?(payload)
        payload[:exception] ||
          payload[:cached] ||
          IGNORED_PAYLOADS.include?(payload[:name]) ||
          !payload[:sql].match?(EXPLAINED_SQLS)
      end
    end

    class << self
      delegate :start, :reset, :collect, :collect=, :collect?, :queries, to: :instance

      private
        def instance
          ActiveSupport::IsolatedExecutionState[:active_record_explain_registry] ||= new
        end
    end

    attr_accessor :collect
    attr_reader :queries

    def initialize
      reset
    end

    def start
      Subscriber.ensure_subscribed
      @collect = true
    end

    def collect?
      @collect
    end

    def reset
      @collect = false
      @queries = []
    end
  end
end
