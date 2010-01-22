require "action_dispatch"
require "rails"

module ActionDispatch
  class Railtie < Rails::Railtie
    plugin_name :action_dispatch

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