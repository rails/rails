# frozen_string_literal: true

require "active_record/database_configurations"

module ActiveRecord
  module Tasks # :nodoc:
    class DatabaseNotSupported < StandardError; end # :nodoc:

    # = Active Record \DatabaseTasks
    #
    # ActiveRecord::Tasks::DatabaseTasks is a utility class, which encapsulates
    # logic behind common tasks used to manage database and migrations.
    #
    # The tasks defined here are used with \Rails commands provided by Active Record.
    #
    # In order to use DatabaseTasks, a few config values need to be set. All the needed
    # config values are set by \Rails already, so it's necessary to do it only if you
    # want to change the defaults or when you want to use Active Record outside of \Rails
    # (in such case after configuring the database tasks, you can also use the rake tasks
    # defined in Active Record).
    #
    # The possible config values are:
    #
    # * +env+: current environment (like Rails.env).
    # * +database_configuration+: configuration of your databases (as in +config/database.yml+).
    # * +db_dir+: your +db+ directory.
    # * +fixtures_path+: a path to fixtures directory.
    # * +migrations_paths+: a list of paths to directories with migrations.
    # * +seed_loader+: an object which will load seeds, it needs to respond to the +load_seed+ method.
    # * +root+: a path to the root of the application.
    #
    # Example usage of DatabaseTasks outside \Rails could look as such:
    #
    #   include ActiveRecord::Tasks
    #   DatabaseTasks.database_configuration = YAML.load_file('my_database_config.yml')
    #   DatabaseTasks.db_dir = 'db'
    #   # other settings...
    #
    #   DatabaseTasks.create_current('production')
    module DatabaseTasks
      ##
      # :singleton-method:
      # Extra flags passed to database CLI tool (mysqldump/pg_dump) when calling db:schema:dump
      # It can be used as a string/array (the typical case) or a hash (when you use multiple adapters)
      # Example:
      #   ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = {
      #     mysql2: ['--no-defaults', '--skip-add-drop-table'],
      #     postgres: '--no-tablespaces'
      #   }
      mattr_accessor :structure_dump_flags, instance_accessor: false

      ##
      # :singleton-method:
      # Extra flags passed to database CLI tool when calling db:schema:load
      # It can be used as a string/array (the typical case) or a hash (when you use multiple adapters)
      mattr_accessor :structure_load_flags, instance_accessor: false

      extend self

      attr_writer :db_dir, :migrations_paths, :fixtures_path, :root, :env, :seed_loader
      attr_accessor :database_configuration

      LOCAL_HOSTS = ["127.0.0.1", "localhost"]

      def check_protected_environments!(environment = env)
        return if ENV["DISABLE_DATABASE_ENVIRONMENT_CHECK"]

        configs_for(env_name: environment).each do |db_config|
          check_current_protected_environment!(db_config)
        end
      end

      def register_task(pattern, task)
        @tasks ||= {}
        @tasks[pattern] = task
      end

      register_task(/mysql/,        "ActiveRecord::Tasks::MySQLDatabaseTasks")
      register_task(/trilogy/,      "ActiveRecord::Tasks::MySQLDatabaseTasks")
      register_task(/postgresql/,   "ActiveRecord::Tasks::PostgreSQLDatabaseTasks")
      register_task(/sqlite/,       "ActiveRecord::Tasks::SQLiteDatabaseTasks")

      def db_dir
        @db_dir ||= Rails.application.config.paths["db"].first
      end

      def migrations_paths
        @migrations_paths ||= Rails.application.paths["db/migrate"].to_a
      end

      def fixtures_path
        @fixtures_path ||= if ENV["FIXTURES_PATH"]
          File.join(root, ENV["FIXTURES_PATH"])
        else
          File.join(root, "test", "fixtures")
        end
      end

      def root
        @root ||= Rails.root
      end

      def env
        @env ||= Rails.env
      end

      def name
        @name ||= "primary"
      end

      def seed_loader
        @seed_loader ||= Rails.application
      end

      def create(configuration, *arguments)
        db_config = resolve_configuration(configuration)
        database_adapter_for(db_config, *arguments).create
        $stdout.puts "Created database '#{db_config.database}'" if verbose?
      rescue DatabaseAlreadyExists
        $stderr.puts "Database '#{db_config.database}' already exists" if verbose?
      rescue Exception => error
        $stderr.puts error
        $stderr.puts "Couldn't create '#{db_config.database}' database. Please check your configuration."
        raise
      end

      def create_all
        db_config = migration_connection.pool.db_config

        each_local_configuration { |db_config| create(db_config) }

        migration_class.establish_connection(db_config)
      end

      def setup_initial_database_yaml # :nodoc:
        return {} unless defined?(Rails)

        Rails.application.config.load_database_yaml
      end

      def for_each(databases) # :nodoc:
        return {} unless defined?(Rails)

        database_configs = ActiveRecord::DatabaseConfigurations.new(databases).configs_for(env_name: Rails.env)

        # if this is a single database application we don't want tasks for each primary database
        return if database_configs.count == 1

        database_configs.each do |db_config|
          next unless db_config.database_tasks?

          yield db_config.name
        end
      end

      def raise_for_multi_db(environment = env, command:) # :nodoc:
        db_configs = configs_for(env_name: environment)

        if db_configs.count > 1
          dbs_list = []

          db_configs.each do |db|
            dbs_list << "#{command}:#{db.name}"
          end

          raise "You're using a multiple database application. To use `#{command}` you must run the namespaced task with a VERSION. Available tasks are #{dbs_list.to_sentence}."
        end
      end

      def create_current(environment = env, name = nil)
        each_current_configuration(environment, name) { |db_config| create(db_config) }

        migration_class.establish_connection(environment.to_sym)
      end

      def prepare_all
        seed = false
        dump_db_configs = []

        each_current_configuration(env) do |db_config|
          with_temporary_pool(db_config) do
            begin
              database_initialized = migration_connection_pool.schema_migration.table_exists?
            rescue ActiveRecord::NoDatabaseError
              create(db_config)
              retry
            end

            unless database_initialized
              if File.exist?(schema_dump_path(db_config))
                load_schema(db_config, ActiveRecord.schema_format, nil)
              end

              seed = true
            end
          end
        end

        each_current_environment(env) do |environment|
          db_configs_with_versions(environment).sort.each do |version, db_configs|
            dump_db_configs |= db_configs

            db_configs.each do |db_config|
              with_temporary_pool(db_config) do
                migrate(version)
              end
            end
          end
        end

        # Dump schema for databases that were migrated.
        if ActiveRecord.dump_schema_after_migration
          dump_db_configs.each do |db_config|
            with_temporary_pool(db_config) do
              dump_schema(db_config)
            end
          end
        end

        load_seed if seed
      end

      def drop(configuration, *arguments)
        db_config = resolve_configuration(configuration)
        database_adapter_for(db_config, *arguments).drop
        $stdout.puts "Dropped database '#{db_config.database}'" if verbose?
      rescue ActiveRecord::NoDatabaseError
        $stderr.puts "Database '#{db_config.database}' does not exist"
      rescue Exception => error
        $stderr.puts error
        $stderr.puts "Couldn't drop database '#{db_config.database}'"
        raise
      end

      def drop_all
        each_local_configuration { |db_config| drop(db_config) }
      end

      def drop_current(environment = env)
        each_current_configuration(environment) { |db_config| drop(db_config) }
      end

      def truncate_tables(db_config)
        with_temporary_connection(db_config) do |conn|
          conn.truncate_tables(*conn.tables)
        end
      end
      private :truncate_tables

      def truncate_all(environment = env)
        configs_for(env_name: environment).each do |db_config|
          truncate_tables(db_config)
        end
      end

      def migrate(version = nil)
        scope = ENV["SCOPE"]
        verbose_was, Migration.verbose = Migration.verbose, verbose?

        check_target_version

        migration_connection_pool.migration_context.migrate(target_version) do |migration|
          if version.blank?
            scope.blank? || scope == migration.scope
          else
            migration.version == version
          end
        end.tap do |migrations_ran|
          Migration.write("No migrations ran. (using #{scope} scope)") if scope.present? && migrations_ran.empty?
        end

        migration_connection_pool.schema_cache.clear!
      ensure
        Migration.verbose = verbose_was
      end

      def db_configs_with_versions(environment = env) # :nodoc:
        db_configs_with_versions = Hash.new { |h, k| h[k] = [] }

        with_temporary_pool_for_each(env: environment) do |pool|
          db_config = pool.db_config
          versions_to_run = pool.migration_context.pending_migration_versions
          target_version = ActiveRecord::Tasks::DatabaseTasks.target_version

          versions_to_run.each do |version|
            next if target_version && target_version != version
            db_configs_with_versions[version] << db_config
          end
        end

        db_configs_with_versions
      end

      def migrate_status
        unless migration_connection_pool.schema_migration.table_exists?
          Kernel.abort "Schema migrations table does not exist yet."
        end

        # output
        puts "\ndatabase: #{migration_connection_pool.db_config.database}\n\n"
        puts "#{'Status'.center(8)}  #{'Migration ID'.ljust(14)}  Migration Name"
        puts "-" * 50
        migration_connection_pool.migration_context.migrations_status.each do |status, version, name|
          puts "#{status.center(8)}  #{version.ljust(14)}  #{name}"
        end
        puts
      end

      def check_target_version
        if target_version && !Migration.valid_version_format?(ENV["VERSION"])
          raise "Invalid format of target version: `VERSION=#{ENV['VERSION']}`"
        end
      end

      def target_version
        ENV["VERSION"].to_i if ENV["VERSION"] && !ENV["VERSION"].empty?
      end

      def charset_current(env_name = env, db_name = name)
        db_config = configs_for(env_name: env_name, name: db_name)
        charset(db_config)
      end

      def charset(configuration, *arguments)
        db_config = resolve_configuration(configuration)
        database_adapter_for(db_config, *arguments).charset
      end

      def collation_current(env_name = env, db_name = name)
        db_config = configs_for(env_name: env_name, name: db_name)
        collation(db_config)
      end

      def collation(configuration, *arguments)
        db_config = resolve_configuration(configuration)
        database_adapter_for(db_config, *arguments).collation
      end

      def purge(configuration)
        db_config = resolve_configuration(configuration)
        database_adapter_for(db_config).purge
      end

      def purge_all
        each_local_configuration { |db_config| purge(db_config) }
      end

      def purge_current(environment = env)
        each_current_configuration(environment) { |db_config| purge(db_config) }

        migration_class.establish_connection(environment.to_sym)
      end

      def structure_dump(configuration, *arguments)
        db_config = resolve_configuration(configuration)
        filename = arguments.delete_at(0)
        flags = structure_dump_flags_for(db_config.adapter)
        database_adapter_for(db_config, *arguments).structure_dump(filename, flags)
      end

      def structure_load(configuration, *arguments)
        db_config = resolve_configuration(configuration)
        filename = arguments.delete_at(0)
        flags = structure_load_flags_for(db_config.adapter)
        database_adapter_for(db_config, *arguments).structure_load(filename, flags)
      end

      def load_schema(db_config, format = ActiveRecord.schema_format, file = nil) # :nodoc:
        file ||= schema_dump_path(db_config, format)
        return unless file

        verbose_was, Migration.verbose = Migration.verbose, verbose? && ENV["VERBOSE"]
        check_schema_file(file)

        case format
        when :ruby
          load(file)
        when :sql
          structure_load(db_config, file)
        else
          raise ArgumentError, "unknown format #{format.inspect}"
        end

        migration_connection_pool.internal_metadata.create_table_and_set_flags(db_config.env_name, schema_sha1(file))
      ensure
        Migration.verbose = verbose_was
      end

      def schema_up_to_date?(configuration, format = ActiveRecord.schema_format, file = nil)
        db_config = resolve_configuration(configuration)

        file ||= schema_dump_path(db_config)

        return true unless file && File.exist?(file)

        with_temporary_pool(db_config) do |pool|
          internal_metadata = pool.internal_metadata
          return false unless internal_metadata.enabled?
          return false unless internal_metadata.table_exists?

          internal_metadata[:schema_sha1] == schema_sha1(file)
        end
      end

      def reconstruct_from_schema(db_config, format = ActiveRecord.schema_format, file = nil) # :nodoc:
        file ||= schema_dump_path(db_config, format)

        check_schema_file(file) if file

        with_temporary_pool(db_config, clobber: true) do
          if schema_up_to_date?(db_config, format, file)
            truncate_tables(db_config) unless ENV["SKIP_TEST_DATABASE_TRUNCATE"]
          else
            purge(db_config)
            load_schema(db_config, format, file)
          end
        rescue ActiveRecord::NoDatabaseError
          create(db_config)
          load_schema(db_config, format, file)
        end
      end

      def dump_schema(db_config, format = ActiveRecord.schema_format) # :nodoc:
        return unless db_config.schema_dump

        require "active_record/schema_dumper"
        filename = schema_dump_path(db_config, format)
        return unless filename

        FileUtils.mkdir_p(db_dir)
        case format
        when :ruby
          File.open(filename, "w:utf-8") do |file|
            ActiveRecord::SchemaDumper.dump(migration_connection_pool, file)
          end
        when :sql
          structure_dump(db_config, filename)
          if migration_connection_pool.schema_migration.table_exists?
            File.open(filename, "a") do |f|
              f.puts migration_connection.dump_schema_information
              f.print "\n"
            end
          end
        end
      end

      def schema_dump_path(db_config, format = ActiveRecord.schema_format)
        return ENV["SCHEMA"] if ENV["SCHEMA"]

        filename = db_config.schema_dump(format)
        return unless filename

        if File.dirname(filename) == ActiveRecord::Tasks::DatabaseTasks.db_dir
          filename
        else
          File.join(ActiveRecord::Tasks::DatabaseTasks.db_dir, filename)
        end
      end

      def cache_dump_filename(db_config_or_name, schema_cache_path: nil)
        if db_config_or_name.is_a?(DatabaseConfigurations::DatabaseConfig)
          schema_cache_path ||
            db_config_or_name.schema_cache_path ||
            schema_cache_env ||
            db_config_or_name.default_schema_cache_path(ActiveRecord::Tasks::DatabaseTasks.db_dir)
        else
          ActiveRecord.deprecator.warn(<<~MSG.squish)
            Passing a database name to `cache_dump_filename` is deprecated and will be removed in Rails 8.0. Pass a
            `ActiveRecord::DatabaseConfigurations::DatabaseConfig` object instead.
          MSG

          filename = if ActiveRecord::Base.configurations.primary?(db_config_or_name)
            "schema_cache.yml"
          else
            "#{db_config_or_name}_schema_cache.yml"
          end

          schema_cache_path || schema_cache_env || File.join(ActiveRecord::Tasks::DatabaseTasks.db_dir, filename)
        end
      end

      def load_schema_current(format = ActiveRecord.schema_format, file = nil, environment = env)
        each_current_configuration(environment) do |db_config|
          with_temporary_connection(db_config) do
            load_schema(db_config, format, file)
          end
        end
      end

      def check_schema_file(filename)
        unless File.exist?(filename)
          message = +%{#{filename} doesn't exist yet. Run `bin/rails db:migrate` to create it, then try again.}
          message << %{ If you do not intend to use a database, you should instead alter #{Rails.root}/config/application.rb to limit the frameworks that will be loaded.} if defined?(::Rails.root)
          Kernel.abort message
        end
      end

      def load_seed
        if seed_loader
          seed_loader.load_seed
        else
          raise "You tried to load seed data, but no seed loader is specified. Please specify seed " \
                "loader with ActiveRecord::Tasks::DatabaseTasks.seed_loader = your_seed_loader\n" \
                "Seed loader should respond to load_seed method"
        end
      end

      # Dumps the schema cache in YAML format for the connection into the file
      #
      # ==== Examples
      #   ActiveRecord::Tasks::DatabaseTasks.dump_schema_cache(ActiveRecord::Base.lease_connection, "tmp/schema_dump.yaml")
      def dump_schema_cache(conn_or_pool, filename)
        conn_or_pool.schema_cache.dump_to(filename)
      end

      def clear_schema_cache(filename)
        FileUtils.rm_f filename, verbose: false
      end

      def with_temporary_pool_for_each(env: ActiveRecord::Tasks::DatabaseTasks.env, name: nil, clobber: false, &block) # :nodoc:
        if name
          db_config = ActiveRecord::Base.configurations.configs_for(env_name: env, name: name)
          with_temporary_pool(db_config, clobber: clobber, &block)
        else
          ActiveRecord::Base.configurations.configs_for(env_name: env, name: name).each do |db_config|
            with_temporary_pool(db_config, clobber: clobber, &block)
          end
        end
      end

      def with_temporary_connection(db_config, clobber: false, &block) # :nodoc:
        with_temporary_pool(db_config, clobber: clobber) do |pool|
          pool.with_connection(&block)
        end
      end

      def migration_class # :nodoc:
        ActiveRecord::Base
      end

      def migration_connection # :nodoc:
        migration_class.lease_connection
      end

      def migration_connection_pool # :nodoc:
        migration_class.connection_pool
      end

      private
        def schema_cache_env
          if ENV["SCHEMA_CACHE"]
            ActiveRecord.deprecator.warn(<<~MSG.squish)
              Setting `ENV["SCHEMA_CACHE"]` is deprecated and will be removed in Rails 8.0.
              Configure the `:schema_cache_path` in the database configuration instead.
            MSG

            nil
          end
        end

        def with_temporary_pool(db_config, clobber: false)
          original_db_config = migration_class.connection_db_config
          pool = migration_class.connection_handler.establish_connection(db_config, clobber: clobber)

          yield pool
        ensure
          migration_class.connection_handler.establish_connection(original_db_config, clobber: clobber)
        end

        def configs_for(**options)
          Base.configurations.configs_for(**options)
        end

        def resolve_configuration(configuration)
          Base.configurations.resolve(configuration)
        end

        def verbose?
          ENV["VERBOSE"] ? ENV["VERBOSE"] != "false" : true
        end

        # Create a new instance for the specified db configuration object
        # For classes that have been converted to use db_config objects, pass a
        # `DatabaseConfig`, otherwise pass a `Hash`
        def database_adapter_for(db_config, *arguments)
          klass = class_for_adapter(db_config.adapter)
          converted = klass.respond_to?(:using_database_configurations?) && klass.using_database_configurations?

          config = converted ? db_config : db_config.configuration_hash
          klass.new(config, *arguments)
        end

        def class_for_adapter(adapter)
          _key, task = @tasks.reverse_each.detect { |pattern, _task| adapter[pattern] }
          unless task
            raise DatabaseNotSupported, "Rake tasks not supported by '#{adapter}' adapter"
          end
          task.is_a?(String) ? task.constantize : task
        end

        def each_current_configuration(environment, name = nil)
          each_current_environment(environment) do |env|
            configs_for(env_name: env).each do |db_config|
              next if name && name != db_config.name

              yield db_config
            end
          end
        end

        def each_current_environment(environment, &block)
          environments = [environment]
          environments << "test" if environment == "development" && !ENV["SKIP_TEST_DATABASE"] && !ENV["DATABASE_URL"]
          environments.each(&block)
        end

        def each_local_configuration
          configs_for.each do |db_config|
            next unless db_config.database

            if local_database?(db_config)
              yield db_config
            else
              $stderr.puts "This task only modifies local databases. #{db_config.database} is on a remote host."
            end
          end
        end

        def local_database?(db_config)
          host = db_config.host
          host.blank? || LOCAL_HOSTS.include?(host)
        end

        def schema_sha1(file)
          OpenSSL::Digest::SHA1.hexdigest(File.read(file))
        end

        def structure_dump_flags_for(adapter)
          if structure_dump_flags.is_a?(Hash)
            structure_dump_flags[adapter.to_sym]
          else
            structure_dump_flags
          end
        end

        def structure_load_flags_for(adapter)
          if structure_load_flags.is_a?(Hash)
            structure_load_flags[adapter.to_sym]
          else
            structure_load_flags
          end
        end

        def check_current_protected_environment!(db_config)
          with_temporary_pool(db_config) do |pool|
            migration_context = pool.migration_context
            current = migration_context.current_environment
            stored  = migration_context.last_stored_environment

            if migration_context.protected_environment?
              raise ActiveRecord::ProtectedEnvironmentError.new(stored)
            end

            if stored && stored != current
              raise ActiveRecord::EnvironmentMismatchError.new(current: current, stored: stored)
            end
          rescue ActiveRecord::NoDatabaseError
          end
        end
    end
  end
end
