require "action_controller"
require "rails"

module ActionController
  class Railtie < Rails::Railtie
    plugin_name :action_controller

    require "action_controller/railties/subscriber"
    subscriber ActionController::Railties::Subscriber.new

    initializer "action_controller.set_configs" do |app|
      app.config.action_controller.each do |k,v|
        ActionController::Base.send "#{k}=", v
      end
    end

    # TODO: ActionController::Base.logger should delegate to its own config.logger
    initializer "action_controller.logger" do
      ActionController::Base.logger ||= Rails.logger
    end

    # Routing must be initialized after plugins to allow the former to extend the routes
    initializer "action_controller.initialize_routing" do |app|
      app.route_configuration_files << app.config.routes_configuration_file
      app.route_configuration_files << app.config.builtin_routes_configuration_file
      app.reload_routes!
    end

    initializer "action_controller.initialize_framework_caches" do
      ActionController::Base.cache_store ||= RAILS_CACHE
    end

    # Sets +ActionController::Base#view_paths+ and +ActionMailer::Base#template_root+
    # (but only for those frameworks that are to be loaded). If the framework's
    # paths have already been set, it is not changed, otherwise it is
    # set to use Configuration#view_path.
    initializer "action_controller.initialize_framework_views" do |app|
      # TODO: this should be combined with the logic for default config.action_controller.view_paths
      view_path = ActionView::PathSet.type_cast(app.config.view_path, app.config.cache_classes)
      ActionController::Base.view_paths = view_path if ActionController::Base.view_paths.blank?
    end

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

    initializer "action_controller.initialize_metal" do |app|
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
    initializer "action_controller.prepare_dispatcher" do |app|
      # TODO: This used to say unless defined?(Dispatcher). Find out why and fix.
      # Notice that at this point, ActionDispatch::Callbacks were already loaded.
      require 'rails/dispatcher'
      ActionController::Dispatcher.prepare_each_request = true unless app.config.cache_classes

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
