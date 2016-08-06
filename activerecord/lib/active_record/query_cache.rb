module ActiveRecord
  # = Active Record Query Cache
  class QueryCache
    module ClassMethods
      # Enable the query cache within the block if Active Record is configured.
      # If it's not, it will execute the given block.
      def cache(&block)
        if connected?
          connection.cache(&block)
        else
          yield
        end
      end

      # Disable the query cache within the block if Active Record is configured.
      # If it's not, it will execute the given block.
      def uncached(&block)
        if connected?
          connection.uncached(&block)
        else
          yield
        end
      end

      # Enable the query cache for any connections made on this thread
      def enable_query_cache!
        ActiveRecord::RuntimeRegistry.query_cache_enabled = true
        if connected?
          connection.enable_query_cache!
        end
      end

      # Whether the query cache is enabled for the current thread
      def query_cache_enabled?
        ActiveRecord::RuntimeRegistry.query_cache_enabled
      end

      # Disables the query cache for the current connection, and stops enabling
      # the query cache for future connections which are established
      def disable_query_cache!
        ActiveRecord::RuntimeRegistry.query_cache_enabled = false
        if connected?
          connection.disable_query_cache!
        end
      end
    end

    def self.run
      enabled_before_run = ActiveRecord::Base.query_cache_enabled?
      ActiveRecord::Base.enable_query_cache!

      enabled_before_run
    end

    def self.complete(enabled_before_run)
      if ActiveRecord::Base.connected?
        ActiveRecord::Base.connection.clear_query_cache
      end
      ActiveRecord::Base.disable_query_cache! unless enabled_before_run
    end

    def self.install_executor_hooks(executor = ActiveSupport::Executor)
      executor.register_hook(self)

      executor.to_complete do
        unless ActiveRecord::Base.connected? && ActiveRecord::Base.connection.transaction_open?
          ActiveRecord::Base.clear_active_connections!
        end
      end
    end
  end
end
