# frozen_string_literal: true

require 'active_record/database_configurations'

module ActiveRecord
  module Tasks # :nodoc:
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
      # Extra flags passed to database CLI tool (mysqldump/pg_dump) when calling db:schema:dump
      mattr_accessor :structure_dump_flags, instance_accessor: false

      ##
      # :singleton-method:
      # Extra flags passed to database CLI tool when calling db:schema:load
      mattr_accessor :structure_load_flags, instance_accessor: false

      extend self

      attr_writer :current_config, :db_dir, :migrations_paths, :fixtures_path, :root, :env, :seed_loader
      deprecate :current_config=
      attr_accessor :database_configuration

      LOCAL_HOSTS = ['127.0.0.1', 'localhost']

      def check_protected_environments!
        unless ENV['DISABLE_DATABASE_ENVIRONMENT_CHECK']
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

      register_task(/mysql/,        'ActiveRecord::Tasks::MySQLDatabaseTasks')
      register_task(/postgresql/,   'ActiveRecord::Tasks::PostgreSQLDatabaseTasks')
      register_task(/sqlite/,       'ActiveRecord::Tasks::SQLiteDatabaseTasks')

      def db_dir
        @db_dir ||= Rails.application.config.paths['db'].first
      end

      def migrations_paths
        @migrations_paths ||= Rails.application.paths['db/migrate'].to_a
      end

      def fixtures_path
        @fixtures_path ||= if ENV['FIXTURES_PATH']
          File.join(root, ENV['FIXTURES_PATH'])
        else
          File.join(root, 'test', 'fixtures')
        end
      end

      def root
        @root ||= Rails.root
      end

      def env
        @env ||= Rails.env
      end

      def spec
        @spec ||= 'primary'
      end
      deprecate spec: 'please use name instead'

      def name
        @name ||= 'primary'
      end

      def seed_loader
        @seed_loader ||= Rails.application
      end

      def current_config(options = {})
        if options.has_key?(:config)
          @current_config = options[:config]
        else
          env_name = options[:env] || env
          name = options[:spec] || 'primary'

          @current_config ||= ActiveRecord::Base.configurations.configs_for(env_name: env_name, name: name)&.configuration_hash
        end
      end
      deprecate :current_config

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
        old_pool = ActiveRecord::Base.connection_handler.retrieve_connection_pool(ActiveRecord::Base.connection_specification_name)
        each_local_configuration { |db_config| create(db_config) }
        if old_pool
          ActiveRecord::Base.connection_handler.establish_connection(old_pool.db_config)
        end
      end

      def setup_initial_database_yaml
        return {} unless defined?(Rails)

        begin
          Rails.application.config.load_database_yaml
        rescue
          $stderr.puts "Rails couldn't infer whether you are using multiple databases from your database.yml and can't generate the tasks for the non-primary databases. If you'd like to use this feature, please simplify your ERB."

          {}
        end
      end

      def for_each(databases)
        return {} unless defined?(Rails)

        database_configs = ActiveRecord::DatabaseConfigurations.new(databases).configs_for(env_name: Rails.env)

        # if this is a single database application we don't want tasks for each primary database
        return if database_configs.count == 1

        database_configs.each do |db_config|
          yield db_config.name
        end
      end

      def raise_for_multi_db(environment = env, command:)
        db_configs = ActiveRecord::Base.configurations.configs_for(env_name: environment)

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
        ActiveRecord::Base.establish_connection(environment.to_sym)
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
        ActiveRecord::Base.establish_connection(db_config)

        connection = ActiveRecord::Base.connection
        connection.truncate_tables(*connection.tables)
      end
      private :truncate_tables

      def truncate_all(environment = env)
        ActiveRecord::Base.configurations.configs_for(env_name: environment).each do |db_config|
          truncate_tables(db_config)
        end
      end

      def migrate
        check_target_version

        scope = ENV['SCOPE']
        verbose_was, Migration.verbose = Migration.verbose, verbose?

        Base.connection.migration_context.migrate(target_version) do |migration|
          scope.blank? || scope == migration.scope
        end

        ActiveRecord::Base.clear_cache!
      ensure
        Migration.verbose = verbose_was
      end

      def migrate_status
        unless ActiveRecord::Base.connection.schema_migration.table_exists?
          Kernel.abort 'Schema migrations table does not exist yet.'
        end

        # output
        puts "\ndatabase: #{ActiveRecord::Base.connection_db_config.database}\n\n"
        puts "#{'Status'.center(8)}  #{'Migration ID'.ljust(14)}  Migration Name"
        puts '-' * 50
        ActiveRecord::Base.connection.migration_context.migrations_status.each do |status, version, name|
          puts "#{status.center(8)}  #{version.ljust(14)}  #{name}"
        end
        puts
      end

      def check_target_version
        if target_version && !(Migration::MigrationFilenameRegexp.match?(ENV['VERSION']) || /\A\d+\z/.match?(ENV['VERSION']))
          raise "Invalid format of target version: `VERSION=#{ENV['VERSION']}`"
        end
      end

      def target_version
        ENV['VERSION'].to_i if ENV['VERSION'] && !ENV['VERSION'].empty?
      end

      def charset_current(env_name = env, db_name = name)
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: env_name, name: db_name)
        charset(db_config)
      end

      def charset(configuration, *arguments)
        db_config = resolve_configuration(configuration)
        database_adapter_for(db_config, *arguments).charset
      end

      def collation_current(env_name = env, db_name = name)
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: env_name, name: db_name)
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
        ActiveRecord::Base.establish_connection(environment.to_sym)
      end

      def structure_dump(configuration, *arguments)
        db_config = resolve_configuration(configuration)
        filename = arguments.delete_at(0)
        database_adapter_for(db_config, *arguments).structure_dump(filename, structure_dump_flags)
      end

      def structure_load(configuration, *arguments)
        db_config = resolve_configuration(configuration)
        filename = arguments.delete_at(0)
        database_adapter_for(db_config, *arguments).structure_load(filename, structure_load_flags)
      end

      def load_schema(db_config, format = ActiveRecord::Base.schema_format, file = nil) # :nodoc:
        file ||= dump_filename(db_config.name, format)

        verbose_was, Migration.verbose = Migration.verbose, verbose? && ENV['VERBOSE']
        check_schema_file(file)
        ActiveRecord::Base.establish_connection(db_config)

        case format
        when :ruby
          load(file)
        when :sql
          structure_load(db_config, file)
        else
          raise ArgumentError, "unknown format #{format.inspect}"
        end
        ActiveRecord::InternalMetadata.create_table
        ActiveRecord::InternalMetadata[:environment] = db_config.env_name
        ActiveRecord::InternalMetadata[:schema_sha1] = schema_sha1(file)
      ensure
        Migration.verbose = verbose_was
      end

      def schema_up_to_date?(configuration, format = ActiveRecord::Base.schema_format, file = nil, environment = nil, name = nil)
        db_config = resolve_configuration(configuration)

        if environment || name
          ActiveSupport::Deprecation.warn('`environment` and `name` will be removed as parameters in 6.2.0, you may now pass an ActiveRecord::DatabaseConfigurations::DatabaseConfig as `configuration` instead.')
        end

        name ||= db_config.name

        file ||= dump_filename(name, format)

        return true unless File.exist?(file)

        ActiveRecord::Base.establish_connection(db_config)

        return false unless ActiveRecord::InternalMetadata.enabled?
        return false unless ActiveRecord::InternalMetadata.table_exists?

        ActiveRecord::InternalMetadata[:schema_sha1] == schema_sha1(file)
      end

      def reconstruct_from_schema(db_config, format = ActiveRecord::Base.schema_format, file = nil) # :nodoc:
        file ||= dump_filename(db_config.name, format)

        check_schema_file(file)

        ActiveRecord::Base.establish_connection(db_config)

        if schema_up_to_date?(db_config, format, file)
          truncate_tables(db_config)
        else
          purge(db_config)
          load_schema(db_config, format, file)
        end
      rescue ActiveRecord::NoDatabaseError
        create(db_config)
        load_schema(db_config, format, file)
      end

      def dump_schema(db_config, format = ActiveRecord::Base.schema_format) # :nodoc:
        require 'active_record/schema_dumper'
        filename = dump_filename(db_config.name, format)
        connection = ActiveRecord::Base.connection

        case format
        when :ruby
          File.open(filename, 'w:utf-8') do |file|
            ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
          end
        when :sql
          structure_dump(db_config, filename)
          if connection.schema_migration.table_exists?
            File.open(filename, 'a') do |f|
              f.puts connection.dump_schema_information
              f.print "\n"
            end
          end
        end
      end

      def schema_file(format = ActiveRecord::Base.schema_format)
        File.join(db_dir, schema_file_type(format))
      end

      def schema_file_type(format = ActiveRecord::Base.schema_format)
        case format
        when :ruby
          'schema.rb'
        when :sql
          'structure.sql'
        end
      end

      def dump_filename(db_config_name, format = ActiveRecord::Base.schema_format)
        filename = if ActiveRecord::Base.configurations.primary?(db_config_name)
          schema_file_type(format)
        else
          "#{db_config_name}_#{schema_file_type(format)}"
        end

        ENV['SCHEMA'] || File.join(ActiveRecord::Tasks::DatabaseTasks.db_dir, filename)
      end

      def cache_dump_filename(db_config_name, schema_cache_path: nil)
        filename = if ActiveRecord::Base.configurations.primary?(db_config_name)
          'schema_cache.yml'
        else
          "#{db_config_name}_schema_cache.yml"
        end

        schema_cache_path || ENV['SCHEMA_CACHE'] || File.join(ActiveRecord::Tasks::DatabaseTasks.db_dir, filename)
      end

      def load_schema_current(format = ActiveRecord::Base.schema_format, file = nil, environment = env)
        each_current_configuration(environment) do |db_config|
          load_schema(db_config, format, file)
        end
        ActiveRecord::Base.establish_connection(environment.to_sym)
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
          raise 'You tried to load seed data, but no seed loader is specified. Please specify seed ' \
                "loader with ActiveRecord::Tasks::DatabaseTasks.seed_loader = your_seed_loader\n" \
                'Seed loader should respond to load_seed method'
        end
      end

      # Dumps the schema cache in YAML format for the connection into the file
      #
      # ==== Examples:
      #   ActiveRecord::Tasks::DatabaseTasks.dump_schema_cache(ActiveRecord::Base.connection, "tmp/schema_dump.yaml")
      def dump_schema_cache(conn, filename)
        conn.schema_cache.dump_to(filename)
      end

      def clear_schema_cache(filename)
        FileUtils.rm_f filename, verbose: false
      end

      private
        def resolve_configuration(configuration)
          Base.configurations.resolve(configuration)
        end

        def verbose?
          ENV['VERBOSE'] ? ENV['VERBOSE'] != 'false' : true
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
          _key, task = @tasks.each_pair.detect { |pattern, _task| adapter[pattern] }
          unless task
            raise DatabaseNotSupported, "Rake tasks not supported by '#{adapter}' adapter"
          end
          task.is_a?(String) ? task.constantize : task
        end

        def each_current_configuration(environment, name = nil)
          environments = [environment]
          environments << 'test' if environment == 'development' && !ENV['DATABASE_URL']

          environments.each do |env|
            ActiveRecord::Base.configurations.configs_for(env_name: env).each do |db_config|
              next if name && name != db_config.name

              yield db_config
            end
          end
        end

        def each_local_configuration
          ActiveRecord::Base.configurations.configs_for.each do |db_config|
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
          Digest::SHA1.hexdigest(File.read(file))
        end
    end
  end
end
