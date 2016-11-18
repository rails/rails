module Rails
  class Application
    class DefaultMiddlewareStack
      attr_reader :config, :paths, :app

      def initialize(app, config, paths)
        @app = app
        @config = config
        @paths = paths
      end

      def build_stack
        ActionDispatch::MiddlewareStack.new.tap do |middleware|
          if config.force_ssl
            middleware.use ::ActionDispatch::SSL, config.ssl_options
          end

          middleware.use ::Rack::Sendfile, config.action_dispatch.x_sendfile_header

          if config.public_file_server.enabled
            headers = config.public_file_server.headers || {}
            headers["Cache-Control".freeze] = config.static_cache_control if config.static_cache_control

            middleware.use ::ActionDispatch::Static, paths["public"].first, index: config.public_file_server.index_name, headers: headers
          end

          if rack_cache = load_rack_cache
            require "action_dispatch/http/rack_cache"
            middleware.use ::Rack::Cache, rack_cache
          end

          if config.allow_concurrency == false
            # User has explicitly opted out of concurrent request
            # handling: presumably their code is not threadsafe

            middleware.use ::Rack::Lock
          end

          middleware.use ::ActionDispatch::Executor, app.executor

          middleware.use ::Rack::Runtime
          middleware.use ::Rack::MethodOverride unless config.api_only
          middleware.use ::ActionDispatch::RequestId

          # Must come after Rack::MethodOverride to properly log overridden methods
          middleware.use ::Rails::Rack::Logger, config.log_tags
          middleware.use ::ActionDispatch::ShowExceptions, show_exceptions_app
          middleware.use ::ActionDispatch::DebugExceptions, app, config.debug_exception_response_format
          middleware.use ::ActionDispatch::RemoteIp, config.action_dispatch.ip_spoofing_check, config.action_dispatch.trusted_proxies

          unless config.cache_classes
            middleware.use ::ActionDispatch::Reloader, app.reloader
          end

          middleware.use ::ActionDispatch::Callbacks
          middleware.use ::ActionDispatch::Cookies unless config.api_only

          if !config.api_only && config.session_store
            if config.force_ssl && config.ssl_options.fetch(:secure_cookies, true) && !config.session_options.key?(:secure)
              config.session_options[:secure] = true
            end
            middleware.use config.session_store, config.session_options
            middleware.use ::ActionDispatch::Flash
          end

          middleware.use ::Rack::Head
          middleware.use ::Rack::ConditionalGet
          middleware.use ::Rack::ETag, "no-cache"
        end
      end

      private

        def load_rack_cache
          rack_cache = config.action_dispatch.rack_cache
          return unless rack_cache

          begin
            require "rack/cache"
          rescue LoadError => error
            error.message << " Be sure to add rack-cache to your Gemfile"
            raise
          end

          if rack_cache == true
            {
              metastore: "rails:/",
              entitystore: "rails:/",
              verbose: false
            }
          else
            rack_cache
          end
        end

        def show_exceptions_app
          config.exceptions_app || ActionDispatch::PublicExceptions.new(Rails.public_path)
        end
    end
  end
end
