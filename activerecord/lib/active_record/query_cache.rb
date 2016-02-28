module ActiveRecord
  # = Active Record Query Cache
  class QueryCache
    module ClassMethods
      # Enable the query cache within the block if Active Record is configured.
      # If it's not, it will execute the given block.
      def cache(&block)
        if ActiveRecord::Base.connected?
          connection.cache(&block)
        else
          yield
        end
      end

      # Disable the query cache within the block if Active Record is configured.
      # If it's not, it will execute the given block.
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

    def call(env)
      connection    = ActiveRecord::Base.connection
      enabled       = connection.query_cache_enabled
      connection.enable_query_cache!

      response = @app.call(env)
      response[2] = Rack::BodyProxy.new(response[2]) do
        restore_query_cache_settings(connection, enabled)
      end

      response
    rescue Exception => e
      restore_query_cache_settings(connection, enabled)
      raise e
    end

    private

    def restore_query_cache_settings(connection, enabled)
      connection.clear_query_cache
      connection.disable_query_cache! unless enabled
    end

  end
end
