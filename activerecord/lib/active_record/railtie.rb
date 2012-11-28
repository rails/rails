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
  class Railtie < Rails::Railtie # :nodoc:
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


    config.active_record.use_schema_cache_dump = true

    config.eager_load_namespaces << ActiveRecord

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
      console = ActiveSupport::Logger.new(STDERR)
      Rails.logger.extend ActiveSupport::Logger.broadcast console
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

    initializer "active_record.migration_error" do |app|
      if config.active_record.delete(:migration_error) == :page_load
        config.app_middleware.insert_after "::ActionDispatch::Callbacks",
          "ActiveRecord::Migration::CheckPending"
      end
    end

    initializer "active_record.check_schema_cache_dump" do
      if config.active_record.delete(:use_schema_cache_dump)
        config.after_initialize do |app|
          ActiveSupport.on_load(:active_record) do
            filename = File.join(app.config.paths["db"].first, "schema_cache.dump")

            if File.file?(filename)
              cache = Marshal.load File.binread filename
              if cache.version == ActiveRecord::Migrator.current_version
                self.connection.schema_cache = cache
              else
                warn "Ignoring db/schema_cache.dump because it has expired. The current schema version is #{ActiveRecord::Migrator.current_version}, but the one in the cache is #{cache.version}."
              end
            end
          end
        end
      end
    end

    initializer "active_record.set_configs" do |app|
      ActiveSupport.on_load(:active_record) do
        begin
          old_behavior, ActiveSupport::Deprecation.behavior = ActiveSupport::Deprecation.behavior, :stderr
          whitelist_attributes = app.config.active_record.delete(:whitelist_attributes)

          if respond_to?(:mass_assignment_sanitizer=)
            mass_assignment_sanitizer = nil
          else
            mass_assignment_sanitizer = app.config.active_record.delete(:mass_assignment_sanitizer)
          end

          unless whitelist_attributes.nil? && mass_assignment_sanitizer.nil?
            ActiveSupport::Deprecation.warn <<-EOF.strip_heredoc, []
              Model based mass assignment security has been extracted
              out of Rails into a gem. Please use the new recommended protection model for
              params or add `protected_attributes` to your Gemfile to use the old one.

              To disable this message remove the `whitelist_attributes` option from your
              `config/application.rb` file and any `mass_assignment_sanitizer` options
              from your `config/environments/*.rb` files.

              See http://edgeguides.rubyonrails.org/security.html#mass-assignment for more information
            EOF
          end

          unless app.config.active_record.delete(:observers).nil?
            ActiveSupport::Deprecation.warn <<-EOF.strip_heredoc, []
              Active Record Observers has been extracted out of Rails into a gem.
              Please use callbaks or add `rails-observers` to your Gemfile to use observers.

              To disable this message remove the `observers` option from your
              `config/application.rb` or from your initializers.

              See http://edgeguides.rubyonrails.org/4_0_release_notes.html for more information
            EOF
          end
        ensure
          ActiveSupport::Deprecation.behavior = old_behavior
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
        unless ENV['DATABASE_URL']
          self.configurations = app.config.database_configuration
        end
        establish_connection
      end
    end

    initializer "active_record.validate_explain_support" do |app|
      if app.config.active_record[:auto_explain_threshold_in_seconds] &&
        !ActiveRecord::Base.connection.supports_explain?
        warn "auto_explain_threshold_in_seconds is set but will be ignored because your adapter does not support this feature. Please unset the configuration to avoid this warning."
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
      hook = app.config.reload_classes_only_on_change ? :to_prepare : :to_cleanup

      ActiveSupport.on_load(:active_record) do
        ActionDispatch::Reloader.send(hook) do
          if ActiveRecord::Base.connected?
            ActiveRecord::Base.clear_reloadable_connections!
            ActiveRecord::Base.clear_cache!
          end
        end
      end
    end

    initializer "active_record.add_watchable_files" do |app|
      path = app.paths["db"].first
      config.watchable_files.concat ["#{path}/schema.rb", "#{path}/structure.sql"]
    end
  end
end
