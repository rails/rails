# frozen_string_literal: true

module ActiveRecord
  # = Active Record Query Cache
  class QueryCache
    # ActiveRecord::Base extends this module, so these methods are available in models.
    module ClassMethods
      # Enable the query cache within the block if Active Record is configured.
      # If it's not, it will execute the given block.
      def cache(&block)
        if connected? || !configurations.empty?
          pool = connection_pool
          was_enabled = pool.query_cache_enabled
          begin
            pool.enable_query_cache(&block)
          ensure
            pool.clear_query_cache unless was_enabled
          end
        else
          yield
        end
      end

      # Runs the block with the query cache disabled.
      #
      # If the query cache was enabled before the block was executed, it is
      # enabled again after it.
      #
      # Set <tt>dirties: false</tt> to prevent query caches on all connections
      # from being cleared by write operations. (By default, write operations
      # dirty all connections' query caches in case they are replicas whose
      # cache would now be outdated.)
      def uncached(dirties: true, &block)
        if connected? || !configurations.empty?
          connection_pool.disable_query_cache(dirties: dirties, &block)
        else
          yield
        end
      end
    end

    def self.disable_for_current_unit_of_work! # :nodoc:
      ConnectionAdapters::QueryCache.enabled_by_default = false
      ConnectionAdapters::ConnectionPool.each_used_pool(&:reset_query_cache!)
    end

    module ExecutorHooks # :nodoc:
      def self.run
        previous = ConnectionAdapters::QueryCache.enabled_by_default
        ConnectionAdapters::QueryCache.enabled_by_default = true

        already_enabled = nil
        ConnectionAdapters::ConnectionPool.each_used_pool do |pool|
          cache = pool.query_cache
          if cache.enabled
            (already_enabled ||= []) << cache
          else
            pool.prepare_query_cache(cache)
          end
        end

        [previous, already_enabled]
      end

      def self.complete((previous, already_enabled))
        ConnectionAdapters::QueryCache.enabled_by_default = previous

        ConnectionAdapters::ConnectionPool.each_used_pool do |pool|
          pool.reset_query_cache! unless already_enabled&.include?(pool.query_cache)
        end
      end
    end

    def self.install_executor_hooks(executor = ActiveSupport::Executor) # :nodoc:
      executor.register_hook(ExecutorHooks)
    end
  end
end
