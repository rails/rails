
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

    def call(env)
      enabled       = ActiveRecord::Base.connection.query_cache_enabled
      connection_id = ActiveRecord::Base.connection_id
      ActiveRecord::Base.connection.enable_query_cache!

      response = @app.call(env)
      response[2] = Rack::BodyProxy.new(response[2]) do
        restore_query_cache_settings(connection_id, enabled)
      end

      response
    rescue Exception => e
      restore_query_cache_settings(connection_id, enabled)
      raise e
    end

    private

    def restore_query_cache_settings(connection_id, enabled)
      ActiveRecord::Base.connection_id = connection_id
      ActiveRecord::Base.connection.clear_query_cache
      ActiveRecord::Base.connection.disable_query_cache! unless enabled
    end

  end
end
