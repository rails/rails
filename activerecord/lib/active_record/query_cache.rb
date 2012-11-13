require 'active_support/core_ext/object/blank'

module ActiveRecord
  # = Active Record Query Cache
  class QueryCache
    module ClassMethods
      # Enable the query cache within the block if Active Record is configured.
      def cache(&block)
        if ActiveRecord::Base.connected?
          connection.cache(&block)
        else
          yield
        end
      end

      # Disable the query cache within the block if Active Record is configured.
      def uncached(&block)
        if ActiveRecord::Base.connected?
          connection.uncached(&block)
        else
          yield
        end
      end
    end

    def initialize(app)
      @app = app
    end

    class BodyProxy # :nodoc:
      def initialize(original_cache_value, target, connection_id)
        @original_cache_value = original_cache_value
        @target               = target
        @connection_id        = connection_id
      end

      def method_missing(method_sym, *arguments, &block)
        @target.send(method_sym, *arguments, &block)
      end

      def respond_to?(method_sym, include_private = false)
        super || @target.respond_to?(method_sym)
      end

      def each(&block)
        @target.each(&block)
      end

      def close
        @target.close if @target.respond_to?(:close)
      ensure
        ActiveRecord::Base.connection_id = @connection_id
        ActiveRecord::Base.connection.clear_query_cache
        unless @original_cache_value
          ActiveRecord::Base.connection.disable_query_cache!
        end
      end
    end

    def call(env)
      old = ActiveRecord::Base.connection.query_cache_enabled
      ActiveRecord::Base.connection.enable_query_cache!

      status, headers, body = @app.call(env)
      [status, headers, BodyProxy.new(old, body, ActiveRecord::Base.connection_id)]
    rescue Exception => e
      ActiveRecord::Base.connection.clear_query_cache
      unless old
        ActiveRecord::Base.connection.disable_query_cache!
      end
      raise e
    end
  end
end
