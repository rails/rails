# frozen_string_literal: true

require "active_record"
require "rails"
require "active_model/railtie"

# For now, action_controller must always be present with
# Rails, so let's make sure that it gets required before
# here. This is needed for correctly setting up the middleware.
# In the future, this might become an optional require.
require "action_controller/railtie"

module ActiveRecord
  # = Active Record Railtie
  class Railtie < Rails::Railtie # :nodoc:
    config.active_record = ActiveSupport::OrderedOptions.new

    config.app_generators.orm :active_record, migration: true,
                                              timestamps: true

    config.action_dispatch.rescue_responses.merge!(
      "ActiveRecord::RecordNotFound"   => :not_found,
      "ActiveRecord::StaleObjectError" => :conflict,
      "ActiveRecord::RecordInvalid"    => :unprocessable_entity,
      "ActiveRecord::RecordNotSaved"   => :unprocessable_entity
    )

    config.active_record.use_schema_cache_dump = true
    config.active_record.maintain_test_schema = true

    config.active_record.sqlite3 = ActiveSupport::OrderedOptions.new
    config.active_record.sqlite3.represent_boolean_as_integer = nil

    config.eager_load_namespaces << ActiveRecord

    rake_tasks do
      namespace :db do
        task :load_config do
          ActiveRecord::Tasks::DatabaseTasks.database_configuration = Rails.application.config.database_configuration

          if defined?(ENGINE_ROOT) && engine = Rails::Engine.find(ENGINE_ROOT)
            if engine.paths["db/migrate"].existent
              ActiveRecord::Tasks::DatabaseTasks.migrations_paths += engine.paths["db/migrate"].to_a
            end
          end
        end
      end

      load "active_record/railties/databases.rake"
    end

    # When loading console, force ActiveRecord::Base to be loaded
    # to avoid cross references when loading a constant for the
    # first time. Also, make it output to STDERR.
    console do |app|
      require "active_record/railties/console_sandbox" if app.sandbox?
      require "active_record/base"
      unless ActiveSupport::Logger.logger_outputs_to?(Rails.logger, STDERR, STDOUT)
        console = ActiveSupport::Logger.new(STDERR)
        Rails.logger.extend ActiveSupport::Logger.broadcast console
      end
      ActiveRecord::Base.verbose_query_logs = false
    end

    runner do
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

    initializer "active_record.backtrace_cleaner" do
      ActiveSupport.on_load(:active_record) { LogSubscriber.backtrace_cleaner = ::Rails.backtrace_cleaner }
    end

    initializer "active_record.migration_error" do
      if config.active_record.delete(:migration_error) == :page_load
        config.app_middleware.insert_after ::ActionDispatch::Callbacks,
          ActiveRecord::Migration::CheckPending
      end
    end

    initializer "Check for cache versioning support" do
      config.after_initialize do |app|
        ActiveSupport.on_load(:active_record) do
          if app.config.active_record.cache_versioning && Rails.cache
            unless Rails.cache.try(:supports_in_cache_versioning?)
              raise <<-end_error

You're using a cache store `#{Rails.cache.class}` that does not support
"recyclable" cache keys, also known as "in cache versioning". To
fix this issue either disable "recyclable" cache keys by setting:

    config.active_record.cache_versioning = false

Or switching to a cache store that supports this functionality:
https://guides.rubyonrails.org/caching_with_rails.html#cache-stores

end_error
            end
          end
        end
      end
    end

    initializer "active_record.check_schema_cache_dump" do
      if config.active_record.delete(:use_schema_cache_dump)
        config.after_initialize do |app|
          ActiveSupport.on_load(:active_record) do
            filename = File.join(app.config.paths["db"].first, "schema_cache.yml")

            if File.file?(filename)
              current_version = ActiveRecord::Migrator.current_version

              next if current_version.nil?

              cache = YAML.load(File.read(filename))
              if cache.version == current_version
                connection.schema_cache = cache
                connection_pool.schema_cache = cache.dup
              else
                warn "Ignoring db/schema_cache.yml because it has expired. The current schema version is #{current_version}, but the one in the cache is #{cache.version}."
              end
            end
          end
        end
      end
    end

    initializer "active_record.warn_on_records_fetched_greater_than" do
      if config.active_record.warn_on_records_fetched_greater_than
        ActiveSupport.on_load(:active_record) do
          require "active_record/relation/record_fetch_warning"
        end
      end
    end

    initializer "active_record.set_configs" do |app|
      ActiveSupport.on_load(:active_record) do
        configs = app.config.active_record.dup
        configs.delete(:sqlite3)
        configs.each do |k, v|
          send "#{k}=", v
        end
      end
    end

    # This sets the database configuration from Configuration#database_configuration
    # and then establishes the connection.
    initializer "active_record.initialize_database" do
      ActiveSupport.on_load(:active_record) do
        self.configurations = Rails.application.config.database_configuration

        begin
          establish_connection
        rescue ActiveRecord::NoDatabaseError
          warn <<-end_warning
Oops - You have a database configured, but it doesn't exist yet!

Here's how to get started:

  1. Configure your database in config/database.yml.
  2. Run `rails db:create` to create the database.
  3. Run `rails db:setup` to load your database schema.
end_warning
          raise
        end
      end
    end

    # Expose database runtime to controller for logging.
    initializer "active_record.log_runtime" do
      require "active_record/railties/controller_runtime"
      ActiveSupport.on_load(:action_controller) do
        include ActiveRecord::Railties::ControllerRuntime
      end
    end

    initializer "active_record.collection_cache_association_loading" do
      require "active_record/railties/collection_cache_association_loading"
      ActiveSupport.on_load(:action_view) do
        ActionView::PartialRenderer.prepend(ActiveRecord::Railties::CollectionCacheAssociationLoading)
      end
    end

    initializer "active_record.set_reloader_hooks" do
      ActiveSupport.on_load(:active_record) do
        ActiveSupport::Reloader.before_class_unload do
          if ActiveRecord::Base.connected?
            ActiveRecord::Base.clear_cache!
            ActiveRecord::Base.clear_reloadable_connections!
          end
        end
      end
    end

    initializer "active_record.set_executor_hooks" do
      ActiveRecord::QueryCache.install_executor_hooks
    end

    initializer "active_record.add_watchable_files" do |app|
      path = app.paths["db"].first
      config.watchable_files.concat ["#{path}/schema.rb", "#{path}/structure.sql"]
    end

    initializer "active_record.clear_active_connections" do
      config.after_initialize do
        ActiveSupport.on_load(:active_record) do
          # Ideally the application doesn't connect to the database during boot,
          # but sometimes it does. In case it did, we want to empty out the
          # connection pools so that a non-database-using process (e.g. a master
          # process in a forking server model) doesn't retain a needless
          # connection. If it was needed, the incremental cost of reestablishing
          # this connection is trivial: the rest of the pool would need to be
          # populated anyway.

          clear_active_connections!
          flush_idle_connections!
        end
      end
    end

    initializer "active_record.check_represent_sqlite3_boolean_as_integer" do
      config.after_initialize do
        ActiveSupport.on_load(:active_record_sqlite3adapter) do
          represent_boolean_as_integer = Rails.application.config.active_record.sqlite3.delete(:represent_boolean_as_integer)
          unless represent_boolean_as_integer.nil?
            ActiveRecord::ConnectionAdapters::SQLite3Adapter.represent_boolean_as_integer = represent_boolean_as_integer
          end

          unless ActiveRecord::ConnectionAdapters::SQLite3Adapter.represent_boolean_as_integer
            ActiveSupport::Deprecation.warn <<-MSG
Leaving `ActiveRecord::ConnectionAdapters::SQLite3Adapter.represent_boolean_as_integer`
set to false is deprecated. SQLite databases have used 't' and 'f' to serialize
boolean values and must have old data converted to 1 and 0 (its native boolean
serialization) before setting this flag to true. Conversion can be accomplished
by setting up a rake task which runs

  ExampleModel.where("boolean_column = 't'").update_all(boolean_column: 1)
  ExampleModel.where("boolean_column = 'f'").update_all(boolean_column: 0)

for all models and all boolean columns, after which the flag must be set to
true by adding the following to your application.rb file:

  Rails.application.config.active_record.sqlite3.represent_boolean_as_integer = true
MSG
          end
        end
      end
    end

    initializer "active_record.set_filter_attributes" do
      ActiveSupport.on_load(:active_record) do
        self.filter_attributes += Rails.application.config.filter_parameters
      end
    end
  end
end
