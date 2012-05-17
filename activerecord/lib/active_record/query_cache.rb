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

    def call(env)
      enabled       = ActiveRecord::Base.connection.query_cache_enabled
      connection_id = ActiveRecord::Base.connection_id
      ActiveRecord::Base.connection.enable_query_cache!

      response = @app.call(env)
      response[2] = Rack::BodyProxy.new(response[2]) do
        ActiveRecord::Base.connection_id = connection_id
        ActiveRecord::Base.connection.clear_query_cache
        ActiveRecord::Base.connection.disable_query_cache! unless enabled
      end

      response
    rescue Exception => e
      ActiveRecord::Base.connection.clear_query_cache
      ActiveRecord::Base.connection.disable_query_cache! unless enabled
      raise e
    end
  end
end
