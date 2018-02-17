module ActiveRecord
  # = Active Record Query Cache
  class QueryCache
    module ClassMethods
      # Enable the query cache within the block if Active Record is configured.
      # If it's not, it will execute the given block.
      def cache(&block)
        if connected? || !configurations.empty?
          connection.cache(&block)
        else
          yield
        end
      end

      # Disable the query cache within the block if Active Record is configured.
      # If it's not, it will execute the given block.
      def uncached(&block)
        if connected? || !configurations.empty?
          connection.uncached(&block)
        else
          yield
        end
      end
    end

    def self.run
      connection_id = ActiveRecord::Base.connection_id

      caching_pool = ActiveRecord::Base.connection_pool
      caching_was_enabled = caching_pool.query_cache_enabled

      caching_pool.enable_query_cache!

      [caching_pool, caching_was_enabled, connection_id]
    end

    def self.complete((caching_pool, caching_was_enabled, connection_id))
      ActiveRecord::Base.connection_id = connection_id

      caching_pool.disable_query_cache! unless caching_was_enabled

      ActiveRecord::Base.connection_handler.connection_pool_list.each do |pool|
        pool.release_connection if pool.active_connection? && !pool.connection.transaction_open?
      end
    end

    def self.install_executor_hooks(executor = ActiveSupport::Executor)
      executor.register_hook(self)
    end
  end
end
