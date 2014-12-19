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

          if config.serve_static_files
            middleware.use ::ActionDispatch::Static, paths["public"].first, config.static_cache_control
          end

          if rack_cache = load_rack_cache
            require "action_dispatch/http/rack_cache"
            middleware.use ::Rack::Cache, rack_cache
          end

          middleware.use ::Rack::Lock unless allow_concurrency?
          middleware.use ::Rack::Runtime
          middleware.use ::Rack::MethodOverride
          middleware.use ::ActionDispatch::RequestId

          # Must come after Rack::MethodOverride to properly log overridden methods
          middleware.use ::Rails::Rack::Logger, config.log_tags
          middleware.use ::ActionDispatch::ShowExceptions, show_exceptions_app
          middleware.use ::ActionDispatch::DebugExceptions, app
          middleware.use ::ActionDispatch::RemoteIp, config.action_dispatch.ip_spoofing_check, config.action_dispatch.trusted_proxies

          unless config.cache_classes
            middleware.use ::ActionDispatch::Reloader, lambda { reload_dependencies? }
          end

          middleware.use ::ActionDispatch::Callbacks
          middleware.use ::ActionDispatch::Cookies

          if config.session_store
            if config.force_ssl && !config.session_options.key?(:secure)
              config.session_options[:secure] = true
            end
            middleware.use config.session_store, config.session_options
            middleware.use ::ActionDispatch::Flash
          end

          middleware.use ::ActionDispatch::ParamsParser
          middleware.use ::Rack::Head
          middleware.use ::Rack::ConditionalGet
          middleware.use ::Rack::ETag, "no-cache"
        end
      end

      private

        def reload_dependencies?
          config.reload_classes_only_on_change != true || app.reloaders.map(&:updated?).any?
        end

        def allow_concurrency?
          if config.allow_concurrency.nil?
            config.cache_classes && config.eager_load
          else
            config.allow_concurrency
          end
        end

        def load_rack_cache
          rack_cache = config.action_dispatch.rack_cache
          return unless rack_cache

          begin
            require 'rack/cache'
          rescue LoadError => error
            error.message << ' Be sure to add rack-cache to your Gemfile'
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
