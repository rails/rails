# frozen_string_literal: true

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
      pools = []

      ActiveRecord::Base.connection_handlers.each do |key, handler|
        pools.concat(handler.connection_pool_list.reject { |p| p.query_cache_enabled }.each { |p| p.enable_query_cache! })
      end

      pools
    end

    def self.complete(pools)
      pools.each { |pool| pool.disable_query_cache! }

      ActiveRecord::Base.connection_handlers.each do |_, handler|
        handler.connection_pool_list.each do |pool|
          pool.release_connection if pool.active_connection? && !pool.connection.transaction_open?
        end
      end
    end

    def self.install_executor_hooks(executor = ActiveSupport::Executor)
      executor.register_hook(self)
    end
  end
end
