# For now, action_controller must always be present with
# rails, so let's make sure that it gets required before
# here. This is needed for correctly setting up the middleware.
# In the future, this might become an optional require.
require "active_record"
require "action_controller/railtie"
require "rails"

module ActiveRecord
  class Railtie < Rails::Railtie
    plugin_name :active_record

    rake_tasks do
      load "active_record/railties/databases.rake"
    end

    initializer "active_record.set_configs" do |app|
      app.config.active_record.each do |k,v|
        ActiveRecord::Base.send "#{k}=", v
      end
    end

    # This sets the database configuration from Configuration#database_configuration
    # and then establishes the connection.
    initializer "active_record.initialize_database" do |app|
      ActiveRecord::Base.configurations = app.config.database_configuration
      ActiveRecord::Base.establish_connection
    end

    initializer "active_record.initialize_timezone" do
      ActiveRecord::Base.time_zone_aware_attributes = true
      ActiveRecord::Base.default_timezone = :utc
    end

    # Expose database runtime to controller for logging.
    initializer "active_record.log_runtime" do |app|
      require "active_record/railties/controller_runtime"
      ActionController::Base.send :include, ActiveRecord::Railties::ControllerRuntime
    end

    # Setup database middleware after initializers have run
    initializer "active_record.initialize_database_middleware" do |app|
      middleware = app.config.middleware
      if middleware.include?(ActiveRecord::SessionStore)
        middleware.insert_before ActiveRecord::SessionStore, ActiveRecord::ConnectionAdapters::ConnectionManagement
        middleware.insert_before ActiveRecord::SessionStore, ActiveRecord::QueryCache
      else
        middleware.use ActiveRecord::ConnectionAdapters::ConnectionManagement
        middleware.use ActiveRecord::QueryCache
      end
    end

    initializer "active_record.load_observers" do
      ActiveRecord::Base.instantiate_observers
    end

    # TODO: ActiveRecord::Base.logger should delegate to its own config.logger
    initializer "active_record.logger" do
      ActiveRecord::Base.logger ||= ::Rails.logger
    end

    initializer "active_record.notifications" do
      require 'active_support/notifications'

      ActiveSupport::Notifications.subscribe("sql") do |name, before, after, instrumenter_id, payload|
        ActiveRecord::Base.connection.log_info(payload[:sql], payload[:name], (after - before) * 1000)
      end
    end

  end
end
