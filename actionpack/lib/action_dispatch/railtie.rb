require "action_dispatch"
require "rails"

module ActionDispatch
  class Railtie < Rails::Railtie
    plugin_name :action_dispatch

    require "action_dispatch/railties/subscriber"
    subscriber ActionDispatch::Railties::Subscriber.new

    class MetalMiddlewareBuilder
      def initialize(metals)
        @metals = metals
      end

      def new(app)
        ActionDispatch::Cascade.new(@metals, app)
      end

      def name
        ActionDispatch::Cascade.name
      end
      alias_method :to_s, :name
    end

    initializer "action_dispatch.initialize_metal" do |app|
      metal_root = "#{Rails.root}/app/metal"
      load_list = app.config.metals || Dir["#{metal_root}/**/*.rb"]

      metals = load_list.map { |metal|
        metal = File.basename(metal.gsub("#{metal_root}/", ''), '.rb')
        require_dependency metal
        metal.camelize.constantize
      }.compact

      middleware = MetalMiddlewareBuilder.new(metals)
      app.config.middleware.insert_before(:"ActionDispatch::ParamsParser", middleware)
    end

    # Prepare dispatcher callbacks and run 'prepare' callbacks
    initializer "action_dispatch.prepare_dispatcher" do |app|
      # TODO: This used to say unless defined?(Dispatcher). Find out why and fix.
      require 'rails/dispatcher'

      unless app.config.cache_classes
        # Setup dev mode route reloading
        routes_last_modified = app.routes_changed_at
        reload_routes = lambda do
          unless app.routes_changed_at == routes_last_modified
            routes_last_modified = app.routes_changed_at
            app.reload_routes!
          end
        end
        ActionDispatch::Callbacks.before { |callbacks| reload_routes.call }
      end
    end
  end
end