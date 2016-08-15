require "rack/body_proxy"
require "rack/utils"

module ActiveSupport
  module Cache
    module Strategy
      module LocalCache
        #--
        # This class wraps up local storage for middlewares. Only the middleware method should
        # construct them.
        class Middleware # :nodoc:
          attr_reader :name, :local_cache_key

          def initialize(name, local_cache_key)
            @name             = name
            @local_cache_key = local_cache_key
            @app              = nil
          end

          def new(app)
            @app = app
            self
          end

          def call(env)
            LocalCacheRegistry.set_cache_for(local_cache_key, LocalStore.new)
            response = @app.call(env)
            response[2] = ::Rack::BodyProxy.new(response[2]) do
              LocalCacheRegistry.set_cache_for(local_cache_key, nil)
            end
            response
          rescue Rack::Utils::InvalidParameterError
            LocalCacheRegistry.set_cache_for(local_cache_key, nil)
            [400, {}, []]
          rescue Exception
            LocalCacheRegistry.set_cache_for(local_cache_key, nil)
            raise
          end
        end
      end
    end
  end
end
