# frozen_string_literal: true

module ActiveRecord
  module Tasks # :nodoc:
    class DatabaseAlreadyExists < StandardError; end # :nodoc:
    class DatabaseNotSupported < StandardError; end # :nodoc:

    # ActiveRecord::Tasks::DatabaseTasks is a utility class, which encapsulates
    # logic behind common tasks used to manage database and migrations.
    #
    # The tasks defined here are used with Rails commands provided by Active Record.
    #
    # In order to use DatabaseTasks, a few config values need to be set. All the needed
    # config values are set by Rails already, so it's necessary to do it only if you
    # want to change the defaults or when you want to use Active Record outside of Rails
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
    # Example usage of DatabaseTasks outside Rails could look as such:
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
      # Extra flags passed to database CLI tool (mysqldump/pg_dump) when calling db:structure:dump
      mattr_accessor :structure_dump_flags, instance_accessor: false

      ##
      # :singleton-method:
      # Extra flags passed to database CLI tool when calling db:structure:load
      mattr_accessor :structure_load_flags, instance_accessor: false

      extend self

      attr_writer :current_config, :db_dir, :migrations_paths, :fixtures_path, :root, :env, :seed_loader
      attr_accessor :database_configuration

      LOCAL_HOSTS = ["127.0.0.1", "localhost"]

      def check_protected_environments!
        unless ENV["DISABLE_DATABASE_ENVIRONMENT_CHECK"]
          current = ActiveRecord::Base.connection.migration_context.current_environment
          stored  = ActiveRecord::Base.connection.migration_context.last_stored_environment

          if ActiveRecord::Base.connection.migration_context.protected_environment?
            raise ActiveRecord::ProtectedEnvironmentError.new(stored)
          end

          if stored && stored != current
            raise ActiveRecord::EnvironmentMismatchError.new(current: current, stored: stored)
          end
        end
      rescue ActiveRecord::NoDatabaseError
      end

      def register_task(pattern, task)
        @tasks ||= {}
        @tasks[pattern] = task
      end

      register_task(/mysql/,        "ActiveRecord::Tasks::MySQLDatabaseTasks")
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

      def seed_loader
        @seed_loader ||= Rails.application
      end

      def current_config(options = {})
        options.reverse_merge! env: env
        if options.has_key?(:config)
          @current_config = options[:config]
        else
          @current_config ||= ActiveRecord::Base.configurations[options[:env]]
        end
      end

      def create(*arguments)
        configuration = arguments.first
        class_for_adapter(configuration["adapter"]).new(*arguments).create
        $stdout.puts "Created database '#{configuration['database']}'" if verbose?
      rescue DatabaseAlreadyExists
        $stderr.puts "Database '#{configuration['database']}' already exists" if verbose?
      rescue Exception => error
        $stderr.puts error
        $stderr.puts "Couldn't create '#{configuration['database']}' database. Please check your configuration."
        raise
      end

      def create_all
        old_pool = ActiveRecord::Base.connection_handler.retrieve_connection_pool(ActiveRecord::Base.connection_specification_name)
        each_local_configuration { |configuration| create configuration }
        if old_pool
          ActiveRecord::Base.connection_handler.establish_connection(old_pool.spec.to_hash)
        end
      end

      def for_each
        databases = Rails.application.config.load_database_yaml
        database_configs = ActiveRecord::DatabaseConfigurations.configs_for(Rails.env, databases)

        # if this is a single database application we don't want tasks for each primary database
        return if database_configs.count == 1

        database_configs.each do |db_config|
          yield db_config.spec_name
        end
      end

      def create_current(environment = env)
        each_current_configuration(environment) { |configuration|
          create configuration
        }
        ActiveRecord::Base.establish_connection(environment.to_sym)
      end

      def drop(*arguments)
        configuration = arguments.first
        class_for_adapter(configuration["adapter"]).new(*arguments).drop
        $stdout.puts "Dropped database '#{configuration['database']}'" if verbose?
      rescue ActiveRecord::NoDatabaseError
        $stderr.puts "Database '#{configuration['database']}' does not exist"
      rescue Exception => error
        $stderr.puts error
        $stderr.puts "Couldn't drop database '#{configuration['database']}'"
        raise
      end

      def drop_all
        each_local_configuration { |configuration| drop configuration }
      end

      def drop_current(environment = env)
        each_current_configuration(environment) { |configuration|
          drop configuration
        }
      end

      def migrate
        check_target_version

        scope = ENV["SCOPE"]
        verbose_was, Migration.verbose = Migration.verbose, verbose?
        Base.connection.migration_context.migrate(target_version) do |migration|
          scope.blank? || scope == migration.scope
        end
        ActiveRecord::Base.clear_cache!
      ensure
        Migration.verbose = verbose_was
      end

      def check_target_version
        if target_version && !(Migration::MigrationFilenameRegexp.match?(ENV["VERSION"]) || /\A\d+\z/.match?(ENV["VERSION"]))
          raise "Invalid format of target version: `VERSION=#{ENV['VERSION']}`"
        end
      end

      def target_version
        ENV["VERSION"].to_i if ENV["VERSION"] && !ENV["VERSION"].empty?
      end

      def charset_current(environment = env)
        charset ActiveRecord::Base.configurations[environment]
      end

      def charset(*arguments)
        configuration = arguments.first
        class_for_adapter(configuration["adapter"]).new(*arguments).charset
      end

      def collation_current(environment = env)
        collation ActiveRecord::Base.configurations[environment]
      end

      def collation(*arguments)
        configuration = arguments.first
        class_for_adapter(configuration["adapter"]).new(*arguments).collation
      end

      def purge(configuration)
        class_for_adapter(configuration["adapter"]).new(configuration).purge
      end

      def purge_all
        each_local_configuration { |configuration|
          purge configuration
        }
      end

      def purge_current(environment = env)
        each_current_configuration(environment) { |configuration|
          purge configuration
        }
        ActiveRecord::Base.establish_connection(environment.to_sym)
      end

      def structure_dump(*arguments)
        configuration = arguments.first
        filename = arguments.delete_at 1
        class_for_adapter(configuration["adapter"]).new(*arguments).structure_dump(filename, structure_dump_flags)
      end

      def structure_load(*arguments)
        configuration = arguments.first
        filename = arguments.delete_at 1
        class_for_adapter(configuration["adapter"]).new(*arguments).structure_load(filename, structure_load_flags)
      end

      def load_schema(configuration, format = ActiveRecord::Base.schema_format, file = nil, environment = env, spec_name = "primary") # :nodoc:
        file ||= dump_filename(spec_name, format)

        verbose_was, Migration.verbose = Migration.verbose, verbose? && ENV["VERBOSE"]
        check_schema_file(file)
        ActiveRecord::Base.establish_connection(configuration)

        case format
        when :ruby
          load(file)
        when :sql
          structure_load(configuration, file)
        else
          raise ArgumentError, "unknown format #{format.inspect}"
        end
        ActiveRecord::InternalMetadata.create_table
        ActiveRecord::InternalMetadata[:environment] = environment
      ensure
        Migration.verbose = verbose_was
      end

      def schema_file(format = ActiveRecord::Base.schema_format)
        File.join(db_dir, schema_file_type(format))
      end

      def schema_file_type(format = ActiveRecord::Base.schema_format)
        case format
        when :ruby
          "schema.rb"
        when :sql
          "structure.sql"
        end
      end

      def dump_filename(namespace, format = ActiveRecord::Base.schema_format)
        filename = if namespace == "primary"
          schema_file_type(format)
        else
          "#{namespace}_#{schema_file_type(format)}"
        end

        ENV["SCHEMA"] || File.join(ActiveRecord::Tasks::DatabaseTasks.db_dir, filename)
      end

      def load_schema_current(format = ActiveRecord::Base.schema_format, file = nil, environment = env)
        each_current_configuration(environment) { |configuration, spec_name, env|
          load_schema(configuration, format, file, env, spec_name)
        }
        ActiveRecord::Base.establish_connection(environment.to_sym)
      end

      def check_schema_file(filename)
        unless File.exist?(filename)
          message = %{#{filename} doesn't exist yet. Run `rails db:migrate` to create it, then try again.}.dup
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
      # ==== Examples:
      #   ActiveRecord::Tasks::DatabaseTasks.dump_schema_cache(ActiveRecord::Base.connection, "tmp/schema_dump.yaml")
      def dump_schema_cache(conn, filename)
        conn.schema_cache.clear!
        conn.data_sources.each { |table| conn.schema_cache.add(table) }
        open(filename, "wb") { |f| f.write(YAML.dump(conn.schema_cache)) }
      end

      private
        def verbose?
          ENV["VERBOSE"] ? ENV["VERBOSE"] != "false" : true
        end

        def class_for_adapter(adapter)
          _key, task = @tasks.each_pair.detect { |pattern, _task| adapter[pattern] }
          unless task
            raise DatabaseNotSupported, "Rake tasks not supported by '#{adapter}' adapter"
          end
          task.is_a?(String) ? task.constantize : task
        end

        def each_current_configuration(environment)
          environments = [environment]
          environments << "test" if environment == "development"

          environments.each do |env|
            ActiveRecord::DatabaseConfigurations.configs_for(env) do |spec_name, configuration|
              yield configuration, spec_name, env
            end
          end
        end

        def each_local_configuration
          ActiveRecord::Base.configurations.each_value do |configuration|
            next unless configuration["database"]

            if local_database?(configuration)
              yield configuration
            else
              $stderr.puts "This task only modifies local databases. #{configuration['database']} is on a remote host."
            end
          end
        end

        def local_database?(configuration)
          configuration["host"].blank? || LOCAL_HOSTS.include?(configuration["host"])
        end
    end
  end
end
