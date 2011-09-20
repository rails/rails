require 'active_support/core_ext/object/blank'

module ActiveRecord
  # = Active Record Query Cache
  class QueryCache
    module ClassMethods
      # Enable the query cache within the block if Active Record is configured.
      def cache(&block)
        if ActiveRecord::Base.configurations.blank?
          yield
        else
          connection.cache(&block)
        end
      end

      # Disable the query cache within the block if Active Record is configured.
      def uncached(&block)
        if ActiveRecord::Base.configurations.blank?
          yield
        else
          connection.uncached(&block)
        end
      end
    end

    def initialize(app)
      @app = app
    end

    class BodyProxy # :nodoc:
      def initialize(original_cache_value, target)
        @original_cache_value = original_cache_value
        @target               = target
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
      [status, headers, BodyProxy.new(old, body)]
    rescue Exception => e
      ActiveRecord::Base.connection.clear_query_cache
      unless old
        ActiveRecord::Base.connection.disable_query_cache!
      end
      raise e
    end
  end
end
