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
      ActiveRecord::Base.connection.enable_query_cache!
    end

    def self.complete(_)
      unless ActiveRecord::Base.connected? && ActiveRecord::Base.connection.transaction_open?
        ActiveRecord::Base.clear_active_connections!
      end
    end

    def self.install_executor_hooks(executor = ActiveSupport::Executor)
      executor.register_hook(self)
    end
  end
end
