# frozen_string_literal: true

module ActiveRecord
  # = Active Record Query Cache
  class QueryCache
    module ClassMethods
      # Enable the query cache within the block if Active Record is configured.
      # If it's not, it will execute the given block.
      def cache(&block)
        if connected? || !Base.configurations.empty?
          connection.cache(&block)
        else
          yield
        end
      end

      # Disable the query cache within the block if Active Record is configured.
      # If it's not, it will execute the given block.
      def uncached(&block)
        if connected? || !Base.configurations.empty?
          connection.uncached(&block)
        else
          yield
        end
      end
    end

    def self.run
      ActiveRecord::Base.connection_handler.connection_pool_list.map do |pool|
        caching_was_enabled = pool.query_cache_enabled

        pool.enable_query_cache!

        [pool, caching_was_enabled]
      end
    end

    def self.complete(caching_pools)
      caching_pools.each do |pool, caching_was_enabled|
        pool.disable_query_cache! unless caching_was_enabled
      end

      ActiveRecord::Base.connection_handler.connection_pool_list.each do |pool|
        pool.release_connection if pool.active_connection? && !pool.connection.transaction_open?
      end
    end

    def self.install_executor_hooks(executor = ActiveSupport::Executor)
      executor.register_hook(self)
    end
  end
end
