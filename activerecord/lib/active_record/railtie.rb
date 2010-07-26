require "active_record"
require "rails"
require "active_model/railtie"

# For now, action_controller must always be present with
# rails, so let's make sure that it gets required before
# here. This is needed for correctly setting up the middleware.
# In the future, this might become an optional require.
require "action_controller/railtie"

module ActiveRecord
  # = Active Record Railtie
  class Railtie < Rails::Railtie
    config.active_record = ActiveSupport::OrderedOptions.new

    config.generators.orm :active_record, :migration => true,
                                          :timestamps => true

    config.app_middleware.insert_after "::ActionDispatch::Callbacks", "ActiveRecord::QueryCache"

    rake_tasks do
      load "active_record/railties/databases.rake"
    end

    # When loading console, force ActiveRecord to be loaded to avoid cross
    # references when loading a constant for the first time.
    console do
      ActiveRecord::Base
    end

    initializer "active_record.initialize_timezone" do
      ActiveSupport.on_load(:active_record) do
        self.time_zone_aware_attributes = true
        self.default_timezone = :utc
      end
    end

    initializer "active_record.logger" do
      ActiveSupport.on_load(:active_record) { self.logger ||= ::Rails.logger }
    end

    initializer "active_record.set_configs" do |app|
      ActiveSupport.on_load(:active_record) do
        app.config.active_record.each do |k,v|
          send "#{k}=", v
        end
      end
    end

    # This sets the database configuration from Configuration#database_configuration
    # and then establishes the connection.
    initializer "active_record.initialize_database" do |app|
      ActiveSupport.on_load(:active_record) do
        self.configurations = app.config.database_configuration
        establish_connection
      end
    end

    # Expose database runtime to controller for logging.
    initializer "active_record.log_runtime" do |app|
      require "active_record/railties/controller_runtime"
      ActiveSupport.on_load(:action_controller) do
        include ActiveRecord::Railties::ControllerRuntime
      end
    end

    initializer "active_record.set_dispatch_hooks", :before => :set_clear_dependencies_hook do |app|
      unless app.config.cache_classes
        ActiveSupport.on_load(:active_record) do
          ActionDispatch::Callbacks.after do
            ActiveRecord::Base.clear_reloadable_connections!
          end
        end
      end
    end

    initializer "active_record.add_concurrency_middleware" do |app|
      if app.config.allow_concurrency
        app.config.middleware.insert_after "::ActionDispatch::Callbacks",
          "ActiveRecord::ConnectionAdapters::ConnectionManagement"
      end
    end

    config.after_initialize do
      ActiveSupport.on_load(:active_record) do
        instantiate_observers

        ActionDispatch::Callbacks.to_prepare(:activerecord_instantiate_observers) do
          ActiveRecord::Base.instantiate_observers
        end
      end
    end
  end
end
