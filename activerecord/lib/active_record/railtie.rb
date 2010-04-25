require "active_record"
require "rails"
require "active_model/railtie"

# For now, action_controller must always be present with
# rails, so let's make sure that it gets required before
# here. This is needed for correctly setting up the middleware.
# In the future, this might become an optional require.
require "action_controller/railtie"

module ActiveRecord
  class Railtie < Rails::Railtie
    config.active_record = ActiveSupport::OrderedOptions.new

    config.generators.orm :active_record, :migration => true,
                                          :timestamps => true

    rake_tasks do
      load "active_record/railties/databases.rake"
    end

    require "active_record/railties/log_subscriber"
    log_subscriber :active_record, ActiveRecord::Railties::LogSubscriber.new

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

    # Setup database middleware after initializers have run
    initializer "active_record.initialize_database_middleware", :after => "action_controller.set_configs" do |app|
      middleware = app.config.middleware
      if middleware.include?("ActiveRecord::SessionStore")
        middleware.insert_before "ActiveRecord::SessionStore", ActiveRecord::ConnectionAdapters::ConnectionManagement
        middleware.insert_before "ActiveRecord::SessionStore", ActiveRecord::QueryCache
      else
        middleware.use ActiveRecord::ConnectionAdapters::ConnectionManagement
        middleware.use ActiveRecord::QueryCache
      end
    end

    initializer "active_record.add_observer_hook", :after=>"active_record.set_configs" do |app|
      ActiveSupport.on_load(:active_record) do
        ActionDispatch::Callbacks.to_prepare(:activerecord_instantiate_observers) do
          ActiveRecord::Base.instantiate_observers
        end
      end
    end

    initializer "active_record.instantiate_observers", :after=>"active_record.initialize_database" do
      ActiveSupport.on_load(:active_record) do
        instantiate_observers
      end
    end

    initializer "active_record.set_dispatch_hooks", :before => :set_clear_dependencies_hook do |app|
      ActiveSupport.on_load(:active_record) do
        unless app.config.cache_classes
          ActionDispatch::Callbacks.after do
            ActiveRecord::Base.reset_subclasses
            ActiveRecord::Base.clear_reloadable_connections!
          end
        end
      end
    end
  end
end
