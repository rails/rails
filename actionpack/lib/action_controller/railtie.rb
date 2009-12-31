require "action_controller"
require "rails"

module ActionController
  class Railtie < Rails::Railtie
    plugin_name :action_controller

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

    # Include middleware to serve up static assets
    initializer "action_controller.initialize_static_server" do |app|
      if app.config.serve_static_assets
        app.config.middleware.use(ActionDispatch::Static, Rails.public_path)
      end
    end

    initializer "action_controller.initialize_middleware_stack" do |app|
      middleware = app.config.middleware
      middleware.use(::Rack::Lock, :if => lambda { ActionController::Base.allow_concurrency })
      middleware.use(::Rack::Runtime)
      middleware.use(ActionDispatch::ShowExceptions, lambda { ActionController::Base.consider_all_requests_local })
      middleware.use(ActionDispatch::Callbacks, lambda { ActionController::Dispatcher.prepare_each_request })
      middleware.use(lambda { ActionController::Base.session_store }, lambda { ActionController::Base.session_options })
      middleware.use(ActionDispatch::ParamsParser)
      middleware.use(::Rack::MethodOverride)
      middleware.use(::Rack::Head)
      middleware.use(ActionDispatch::StringCoercion)
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

    initializer "action_controller.initialize_metal" do |app|
      Rails::Rack::Metal.requested_metals = app.config.metals

      app.config.middleware.insert_before(:"ActionDispatch::ParamsParser",
        Rails::Rack::Metal, :if => Rails::Rack::Metal.metals.any?)
    end

    # # Prepare dispatcher callbacks and run 'prepare' callbacks
    initializer "action_controller.prepare_dispatcher" do |app|
      # TODO: This used to say unless defined?(Dispatcher). Find out why and fix.
      require 'rails/dispatcher'

      Dispatcher.define_dispatcher_callbacks(app.config.cache_classes)

      unless app.config.cache_classes
        # Setup dev mode route reloading
        routes_last_modified = app.routes_changed_at
        reload_routes = lambda do
          unless app.routes_changed_at == routes_last_modified
            routes_last_modified = app.routes_changed_at
            app.reload_routes!
          end
        end
        ActionDispatch::Callbacks.before_dispatch { |callbacks| reload_routes.call }
      end
    end

    initializer "action_controller.notifications" do |app|
      require 'active_support/notifications'

      ActiveSupport::Notifications.subscribe do |*args|
        ActionController::Base.log_event(*args) if ActionController::Base.logger
      end
    end

  end
end
