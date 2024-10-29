# frozen_string_literal: true

require "active_record"
require "rails"
require "active_support/core_ext/object/try"
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
    config.active_record.encryption = ActiveSupport::OrderedOptions.new

    config.app_generators.orm :active_record, migration: true,
                                              timestamps: true

    config.action_dispatch.rescue_responses.merge!(
      "ActiveRecord::RecordNotFound"   => :not_found,
      "ActiveRecord::StaleObjectError" => :conflict,
      "ActiveRecord::RecordInvalid"    => :unprocessable_entity,
      "ActiveRecord::RecordNotSaved"   => :unprocessable_entity
    )

    config.active_record.use_schema_cache_dump = true
    config.active_record.check_schema_cache_dump_version = true
    config.active_record.maintain_test_schema = true
    config.active_record.has_many_inversing = false
    config.active_record.query_log_tags_enabled = false
    config.active_record.query_log_tags = [ :application ]
    config.active_record.query_log_tags_format = :legacy
    config.active_record.cache_query_log_tags = false
    config.active_record.raise_on_assign_to_attr_readonly = false
    config.active_record.belongs_to_required_validates_foreign_key = true
    config.active_record.generate_secure_token_on = :create

    config.active_record.queues = ActiveSupport::InheritableOptions.new

    config.eager_load_namespaces << ActiveRecord

    rake_tasks do
      namespace :db do
        task :load_config do
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
        console.level = Rails.logger.level
        Rails.logger.broadcast_to(console)
      end
      ActiveRecord.verbose_query_logs = false
      ActiveRecord::Base.attributes_for_inspect = :all
    end

    runner do
      require "active_record/base"
    end

    initializer "active_record.deprecator", before: :load_environment_config do |app|
      app.deprecators[:active_record] = ActiveRecord.deprecator
    end

    initializer "active_record.initialize_timezone" do
      ActiveSupport.on_load(:active_record) do
        self.time_zone_aware_attributes = true
      end
    end

    initializer "active_record.postgresql_time_zone_aware_types" do
      ActiveSupport.on_load(:active_record_postgresqladapter) do
        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Base.time_zone_aware_types << :timestamptz
        end
      end
    end

    initializer "active_record.logger" do
      ActiveSupport.on_load(:active_record) { self.logger ||= ::Rails.logger }
    end

    initializer "active_record.backtrace_cleaner" do
      ActiveSupport.on_load(:active_record) { LogSubscriber.backtrace_cleaner = ::Rails.backtrace_cleaner }
    end

    initializer "active_record.migration_error" do |app|
      if config.active_record.migration_error == :page_load
        config.app_middleware.insert_after ::ActionDispatch::Callbacks,
          ActiveRecord::Migration::CheckPending,
          file_watcher: app.config.file_watcher
      end
    end

    initializer "active_record.cache_versioning_support" do
      config.after_initialize do |app|
        ActiveSupport.on_load(:active_record) do
          if app.config.active_record.cache_versioning && Rails.cache
            unless Rails.cache.class.try(:supports_cache_versioning?)
              raise <<-end_error

You're using a cache store that doesn't support native cache versioning.
Your best option is to upgrade to a newer version of #{Rails.cache.class}
that supports cache versioning (#{Rails.cache.class}.supports_cache_versioning? #=> true).

Next best, switch to a different cache store that does support cache versioning:
https://guides.rubyonrails.org/caching_with_rails.html#cache-stores.

To keep using the current cache store, you can turn off cache versioning entirely:

    config.active_record.cache_versioning = false

              end_error
            end
          end
        end
      end
    end

    initializer "active_record.copy_schema_cache_config" do
      active_record_config = config.active_record

      ActiveRecord::ConnectionAdapters::SchemaReflection.use_schema_cache_dump = active_record_config.use_schema_cache_dump
      ActiveRecord::ConnectionAdapters::SchemaReflection.check_schema_cache_dump_version = active_record_config.check_schema_cache_dump_version
    end

    initializer "active_record.define_attribute_methods" do |app|
      # For resiliency, it is critical that a Rails application should be
      # able to boot without depending on the database (or any other service)
      # being responsive.
      #
      # Otherwise a bad deploy adding a lot of load on the database may require to
      # entirely shutdown the application so the database can recover before a fixed
      # version can be deployed again.
      #
      # This is why this initializer tries hard not to query the database, and if it
      # does, it makes sure to rescue any possible database error.
      check_schema_cache_dump_version = config.active_record.check_schema_cache_dump_version
      config.after_initialize do
        ActiveSupport.on_load(:active_record) do
          # In development and test we shouldn't eagerly define attribute methods because
          # db:test:prepare will trigger later and might change the schema.
          #
          # Additionally if `check_schema_cache_dump_version` is enabled (which is the default),
          # loading the schema cache dump trigger a database connection to compare the schema
          # versions.
          # This means the attribute methods will be lazily defined when the model is accessed,
          # likely as part of the first few requests or jobs. This isn't good for performance
          # but we unfortunately have to arbitrate between resiliency and performance, and chose
          # resiliency.
          if !check_schema_cache_dump_version && app.config.eager_load && !Rails.env.local?
            begin
              descendants.each do |model|
                if model.connection_pool.schema_reflection.cached?(model.table_name)
                  model.define_attribute_methods
                end
              end
            rescue ActiveRecordError => error
              # Regardless of whether there was already a connection or not, we rescue any database
              # error because it is critical that the application can boot even if the database
              # is unhealthy.
              warn "Failed to define attribute methods because of #{error.class}: #{error.message}"
            end
          end
        end
      end
    end

    initializer "active_record.warn_on_records_fetched_greater_than" do
      if config.active_record.warn_on_records_fetched_greater_than
        ActiveRecord.deprecator.warn <<~MSG.squish
          `config.active_record.warn_on_records_fetched_greater_than` is deprecated and will be
          removed in Rails 8.0.
          Please subscribe to `sql.active_record` notifications and access the row count field to
          detect large result set sizes.
        MSG
        ActiveSupport.on_load(:active_record) do
          require "active_record/relation/record_fetch_warning"
        end
      end
    end

    initializer "active_record.sqlite3_deprecated_warning" do
      if config.active_record.key?(:sqlite3_production_warning)
        config.active_record.delete(:sqlite3_production_warning)
        ActiveRecord.deprecator.warn <<~MSG.squish
          The `config.active_record.sqlite3_production_warning` configuration no longer has any effect
          and can be safely removed.
        MSG
      end
    end

    initializer "active_record.sqlite3_adapter_strict_strings_by_default" do
      config.after_initialize do
        if config.active_record.sqlite3_adapter_strict_strings_by_default
          ActiveSupport.on_load(:active_record_sqlite3adapter) do
            self.strict_strings_by_default = true
          end
        end
      end
    end

    initializer "active_record.postgresql_adapter_decode_dates" do
      config.after_initialize do
        if config.active_record.postgresql_adapter_decode_dates
          ActiveSupport.on_load(:active_record_postgresqladapter) do
            self.decode_dates = true
          end
        end
      end
    end

    initializer "active_record.set_configs" do |app|
      configs = app.config.active_record

      config.after_initialize do
        configs.each do |k, v|
          next if k == :encryption
          setter = "#{k}="
          if ActiveRecord.respond_to?(setter)
            ActiveRecord.send(setter, v)
          end
        end
      end

      ActiveSupport.on_load(:active_record) do
        configs_used_in_other_initializers = configs.except(
          :migration_error,
          :database_selector,
          :database_resolver,
          :database_resolver_context,
          :shard_selector,
          :shard_resolver,
          :query_log_tags_enabled,
          :query_log_tags,
          :query_log_tags_format,
          :cache_query_log_tags,
          :sqlite3_adapter_strict_strings_by_default,
          :check_schema_cache_dump_version,
          :use_schema_cache_dump,
          :postgresql_adapter_decode_dates,
        )

        configs_used_in_other_initializers.each do |k, v|
          next if k == :encryption
          setter = "#{k}="
          # Some existing initializers might rely on Active Record configuration
          # being copied from the config object to their actual destination when
          # `ActiveRecord::Base` is loaded.
          # So to preserve backward compatibility we copy the config a second time.
          if ActiveRecord.respond_to?(setter)
            ActiveRecord.send(setter, v)
          else
            send(setter, v)
          end
        end
      end
    end

    # This sets the database configuration from Configuration#database_configuration
    # and then establishes the connection.
    initializer "active_record.initialize_database" do
      ActiveSupport.on_load(:active_record) do
        self.configurations = Rails.application.config.database_configuration

        establish_connection
      end
    end

    # Expose database runtime for logging.
    initializer "active_record.log_runtime" do
      require "active_record/railties/controller_runtime"
      ActiveSupport.on_load(:action_controller) do
        include ActiveRecord::Railties::ControllerRuntime
      end

      require "active_record/railties/job_runtime"
      ActiveSupport.on_load(:active_job) do
        include ActiveRecord::Railties::JobRuntime
      end
    end

    initializer "active_record.set_reloader_hooks" do
      ActiveSupport.on_load(:active_record) do
        ActiveSupport::Reloader.before_class_unload do
          if ActiveRecord::Base.connected?
            ActiveRecord::Base.clear_cache!
            ActiveRecord::Base.connection_handler.clear_reloadable_connections!(:all)
          end
        end
      end
    end

    initializer "active_record.set_executor_hooks" do
      ActiveRecord::QueryCache.install_executor_hooks
      ActiveRecord::AsynchronousQueriesTracker.install_executor_hooks
      ActiveRecord::ConnectionAdapters::ConnectionPool.install_executor_hooks
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

          connection_handler.clear_active_connections!(:all)
          connection_handler.flush_idle_connections!(:all)
        end
      end
    end

    initializer "active_record.set_filter_attributes" do
      ActiveSupport.on_load(:active_record) do
        self.filter_attributes += Rails.application.config.filter_parameters
      end
    end

    initializer "active_record.set_signed_id_verifier_secret" do
      ActiveSupport.on_load(:active_record) do
        self.signed_id_verifier_secret ||= -> { Rails.application.key_generator.generate_key("active_record/signed_id") }
      end
    end

    initializer "active_record.generated_token_verifier" do
      config.after_initialize do |app|
        ActiveSupport.on_load(:active_record) do
          self.generated_token_verifier ||= app.message_verifier("active_record/token_for")
        end
      end
    end

    initializer "active_record_encryption.configuration" do |app|
      ActiveSupport.on_load(:active_record_encryption) do
        ActiveRecord::Encryption.configure(
          primary_key: app.credentials.dig(:active_record_encryption, :primary_key),
          deterministic_key: app.credentials.dig(:active_record_encryption, :deterministic_key),
          key_derivation_salt: app.credentials.dig(:active_record_encryption, :key_derivation_salt),
          **app.config.active_record.encryption
        )

        auto_filtered_parameters = ActiveRecord::Encryption::AutoFilteredParameters.new(app)
        auto_filtered_parameters.enable if ActiveRecord::Encryption.config.add_to_filter_parameters
      end

      ActiveSupport.on_load(:active_record) do
        # Support extended queries for deterministic attributes and validations
        if ActiveRecord::Encryption.config.extend_queries
          ActiveRecord::Encryption::ExtendedDeterministicQueries.install_support
          ActiveRecord::Encryption::ExtendedDeterministicUniquenessValidator.install_support
        end
      end

      ActiveSupport.on_load(:active_record_fixture_set) do
        # Encrypt Active Record fixtures
        if ActiveRecord::Encryption.config.encrypt_fixtures
          ActiveRecord::Fixture.prepend ActiveRecord::Encryption::EncryptedFixtures
        end
      end
    end

    initializer "active_record.query_log_tags_config" do |app|
      config.after_initialize do
        if app.config.active_record.query_log_tags_enabled
          ActiveRecord.query_transformers << ActiveRecord::QueryLogs
          ActiveRecord::QueryLogs.taggings.merge!(
            application:  Rails.application.class.name.split("::").first,
            pid:          -> { Process.pid.to_s },
            socket:       ->(context) { context[:connection].pool.db_config.socket },
            db_host:      ->(context) { context[:connection].pool.db_config.host },
            database:     ->(context) { context[:connection].pool.db_config.database },
            source_location: -> { QueryLogs.query_source_location }
          )
          ActiveRecord.disable_prepared_statements = true

          if app.config.active_record.query_log_tags.present?
            ActiveRecord::QueryLogs.tags = app.config.active_record.query_log_tags
          end

          if app.config.active_record.query_log_tags_format
            ActiveRecord::QueryLogs.update_formatter(app.config.active_record.query_log_tags_format)
          end

          if app.config.active_record.cache_query_log_tags
            ActiveRecord::QueryLogs.cache_query_log_tags = true
          end
        end
      end
    end

    initializer "active_record.unregister_current_scopes_on_unload" do |app|
      config.after_initialize do
        if app.config.reloading_enabled?
          Rails.autoloaders.main.on_unload do |_cpath, value, _abspath|
            # Conditions are written this way to be robust against custom
            # implementations of value#is_a? or value#<.
            if Class === value && ActiveRecord::Base > value
              value.current_scope = nil
            end
          end
        end
      end
    end

    initializer "active_record.message_pack" do
      ActiveSupport.on_load(:message_pack) do
        ActiveSupport.on_load(:active_record) do
          require "active_record/message_pack"
          ActiveRecord::MessagePack::Extensions.install(ActiveSupport::MessagePack::CacheSerializer)
        end
      end
    end
  end
end
