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

    config.app_generators.orm :active_record, :migration => true,
                                              :timestamps => true

    config.app_middleware.insert_after "::ActionDispatch::Callbacks",
      "ActiveRecord::QueryCache"

    config.app_middleware.insert_after "::ActionDispatch::Callbacks",
      "ActiveRecord::ConnectionAdapters::ConnectionManagement"

    config.action_dispatch.rescue_responses.merge!(
      'ActiveRecord::RecordNotFound'   => :not_found,
      'ActiveRecord::StaleObjectError' => :conflict,
      'ActiveRecord::RecordInvalid'    => :unprocessable_entity,
      'ActiveRecord::RecordNotSaved'   => :unprocessable_entity
    )

    rake_tasks do
      require "active_record/base"
      load "active_record/railties/databases.rake"
    end

    # When loading console, force ActiveRecord::Base to be loaded
    # to avoid cross references when loading a constant for the
    # first time. Also, make it output to STDERR.
    console do |app|
      require "active_record/railties/console_sandbox" if app.sandbox?
      require "active_record/base"
      ActiveRecord::Base.logger = Logger.new(STDERR)
    end

    runner do |app|
      require "active_record/base"
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

    initializer "active_record.identity_map" do |app|
      config.app_middleware.insert_after "::ActionDispatch::Callbacks",
        "ActiveRecord::IdentityMap::Middleware" if config.active_record.delete(:identity_map)
    end

    initializer "active_record.set_configs" do |app|
      ActiveSupport.on_load(:active_record) do
        if app.config.active_record.delete(:whitelist_attributes)
          attr_accessible(nil)
        end
        app.config.active_record.each do |k,v|
          send "#{k}=", v
        end
      end
    end

    # This sets the database configuration from Configuration#database_configuration
    # and then establishes the connection.
    initializer "active_record.initialize_database" do |app|
      ActiveSupport.on_load(:active_record) do
        db_connection_type = "DATABASE_URL"
        unless ENV['DATABASE_URL']
          db_connection_type  = "database.yml"
          self.configurations = app.config.database_configuration
        end
        Rails.logger.info "Connecting to database specified by #{db_connection_type}"

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

    initializer "active_record.set_reloader_hooks" do |app|
      hook = lambda do
        ActiveRecord::Base.clear_reloadable_connections!
        ActiveRecord::Base.clear_cache!
      end

      if app.config.reload_classes_only_on_change
        ActiveSupport.on_load(:active_record) do
          ActionDispatch::Reloader.to_prepare(&hook)
        end
      else
        ActiveSupport.on_load(:active_record) do
          ActionDispatch::Reloader.to_cleanup(&hook)
        end
      end
    end

    initializer "active_record.add_watchable_files" do |app|
      config.watchable_files.concat ["#{app.root}/db/schema.rb", "#{app.root}/db/structure.sql"]
    end

    config.after_initialize do
      ActiveSupport.on_load(:active_record) do
        instantiate_observers

        ActionDispatch::Reloader.to_prepare do
          ActiveRecord::Base.instantiate_observers
        end
      end
    end
  end
end
