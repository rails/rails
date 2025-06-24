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

    module ExecutorHooks # :nodoc:
      def self.run
        ActiveRecord::Base.connection_handler.each_connection_pool.reject(&:query_cache_enabled).each do |pool|
          next if pool.db_config&.query_cache == false
          pool.enable_query_cache!
        end
      end

      def self.complete(pools)
        pools.each do |pool|
          pool.disable_query_cache!
          pool.clear_query_cache
        end
      end
    end

    def self.install_executor_hooks(executor = ActiveSupport::Executor) # :nodoc:
      executor.register_hook(ExecutorHooks)
    end
  end
end
