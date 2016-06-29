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
    end

    def self.run
      connection    = ActiveRecord::Base.connection
      enabled       = connection.query_cache_enabled
      connection.enable_query_cache!

      enabled
    end

    def self.complete(enabled)
      ActiveRecord::Base.connection.clear_query_cache
      ActiveRecord::Base.connection.disable_query_cache! unless enabled
    end

    def self.install_executor_hooks(executor = ActiveSupport::Executor)
      executor.register_hook(self)

      executor.to_complete do
        unless ActiveRecord::Base.connection.transaction_open?
          ActiveRecord::Base.clear_active_connections!
        end
      end
    end
  end
end
