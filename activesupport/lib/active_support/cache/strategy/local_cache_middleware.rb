# frozen_string_literal: true

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
          attr_reader :name
          attr_accessor :cache

          def initialize(name, cache)
            @name = name
            @cache = cache
            @app = nil
          end

          def new(app)
            @app = app
            self
          end

          def call(env)
            cache.new_local_cache
            response = @app.call(env)
            response[2] = ::Rack::BodyProxy.new(response[2]) do
              cache.unset_local_cache
            end
            cleanup_on_body_close = true
            response
          rescue Rack::Utils::InvalidParameterError
            [400, {}, []]
          ensure
            cache.unset_local_cache unless cleanup_on_body_close
          end
        end
      end
    end
  end
end
