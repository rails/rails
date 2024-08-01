# frozen_string_literal: true

module ActiveRecord
  # = Active Record Query Cache
  class QueryCache
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

      # Disable the query cache within the block if Active Record is configured.
      # If it's not, it will execute the given block.
      #
      # Set <tt>dirties: false</tt> to prevent query caches on all connections from being cleared by write operations.
      # (By default, write operations dirty all connections' query caches in case they are replicas whose cache would now be outdated.)
      def uncached(dirties: true, &block)
        if connected? || !configurations.empty?
          connection_pool.disable_query_cache(dirties: dirties, &block)
        else
          yield
        end
      end
    end

    def self.run
      ActiveRecord::Base.connection_handler.each_connection_pool.reject(&:query_cache_enabled).each(&:enable_query_cache!)
    end

    def self.complete(pools)
      pools.each do |pool|
        pool.disable_query_cache!
        pool.clear_query_cache
      end

      ActiveRecord::Base.connection_handler.each_connection_pool do |pool|
        pool.release_connection if pool.active_connection? && !pool.lease_connection.transaction_open?
      end
    end

    def self.install_executor_hooks(executor = ActiveSupport::Executor)
      executor.register_hook(self)
    end
  end
end
