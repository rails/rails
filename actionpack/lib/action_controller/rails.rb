module ActionController
  class Plugin < Rails::Plugin
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
    # ---
    # If Action Controller is not one of the loaded frameworks (Configuration#frameworks)
    # this does nothing. Otherwise, it loads the routing definitions and sets up
    # loading module used to lazily load controllers (Configuration#controller_paths).
    initializer "action_controller.initialize_routing" do |app|
      app.route_configuration_files << app.config.routes_configuration_file
      app.route_configuration_files << app.config.builtin_routes_configuration_file
      app.reload_routes!
    end
  end
end