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

  end
end
