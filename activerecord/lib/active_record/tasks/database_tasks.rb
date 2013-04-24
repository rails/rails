module ActiveRecord
  module Tasks # :nodoc:
    class DatabaseAlreadyExists < StandardError; end # :nodoc:
    class DatabaseNotSupported < StandardError; end # :nodoc:

    # <tt>ActiveRecord::Tasks::DatabaseTasks</tt> is a utility class, which encapsulates
    # logic behind common tasks used to manage database and migrations.
    #
    # The tasks defined here are used in rake tasks provided by Active Record.
    #
    # In order to use DatabaseTasks, a few config values need to be set. All the needed
    # config values are set by Rails already, so it's necessary to do it only if you
    # want to change the defaults or when you want to use Active Record outside of Rails
    # (in such case after configuring the database tasks, you can also use the rake tasks
    # defined in Active Record).
    #
    #
    # The possible config values are:
    #
    #   * +env+: current environment (like Rails.env).
    #   * +database_configuration+: configuration of your databases (as in +config/database.yml+).
    #   * +db_dir+: your +db+ directory.
    #   * +fixtures_path+: a path to fixtures directory.
    #   * +migrations_paths+: a list of paths to directories with migrations.
    #   * +seed_loader+: an object which will load seeds, it needs to respond to the +load_seed+ method.
    #
    # Example usage of +DatabaseTasks+ outside Rails could look as such:
    #
    #   include ActiveRecord::Tasks
    #   DatabaseTasks.database_configuration = YAML.load(File.read('my_database_config.yml'))
    #   DatabaseTasks.db_dir = 'db'
    #   # other settings...
    #
    #   DatabaseTasks.create_current('production')
    module DatabaseTasks
      extend self

      attr_writer :current_config
      attr_accessor :database_configuration, :migrations_paths, :seed_loader, :db_dir,
                    :fixtures_path, :env

      LOCAL_HOSTS    = ['127.0.0.1', 'localhost']

      def register_task(pattern, task)
        @tasks ||= {}
        @tasks[pattern] = task
      end

      register_task(/mysql/,        ActiveRecord::Tasks::MySQLDatabaseTasks)
      register_task(/postgresql/,   ActiveRecord::Tasks::PostgreSQLDatabaseTasks)
      register_task(/sqlite/,       ActiveRecord::Tasks::SQLiteDatabaseTasks)

      register_task(/firebird/,     ActiveRecord::Tasks::FirebirdDatabaseTasks)
      register_task(/sqlserver/,    ActiveRecord::Tasks::SqlserverDatabaseTasks)
      register_task(/(oci|oracle)/, ActiveRecord::Tasks::OracleDatabaseTasks)

      def current_config(options = {})
        options.reverse_merge! :env => env
        if options.has_key?(:config)
          @current_config = options[:config]
        else
          @current_config ||= if ENV['DATABASE_URL']
                                database_url_config
                              else
                                ActiveRecord::Base.configurations[options[:env]]
                              end
        end
      end

      def create(*arguments)
        configuration = arguments.first
        class_for_adapter(configuration['adapter']).new(*arguments).create
      rescue DatabaseAlreadyExists
        $stderr.puts "#{configuration['database']} already exists"
      rescue Exception => error
        $stderr.puts error, *(error.backtrace)
        $stderr.puts "Couldn't create database for #{configuration.inspect}"
      end

      def create_all
        each_local_configuration { |configuration| create configuration }
      end

      def create_current(environment = env)
        each_current_configuration(environment) { |configuration|
          create configuration
        }
        ActiveRecord::Base.establish_connection environment
      end

      def create_database_url
        create database_url_config
      end

      def drop(*arguments)
        configuration = arguments.first
        class_for_adapter(configuration['adapter']).new(*arguments).drop
      rescue Exception => error
        $stderr.puts error, *(error.backtrace)
        $stderr.puts "Couldn't drop #{configuration['database']}"
      end

      def drop_all
        each_local_configuration { |configuration| drop configuration }
      end

      def drop_current(environment = env)
        each_current_configuration(environment) { |configuration|
          drop configuration
        }
      end

      def drop_database_url
        drop database_url_config
      end

      def charset_current(environment = env)
        charset ActiveRecord::Base.configurations[environment]
      end

      def charset(*arguments)
        configuration = arguments.first
        class_for_adapter(configuration['adapter']).new(*arguments).charset
      end

      def collation_current(environment = env)
        collation ActiveRecord::Base.configurations[environment]
      end

      def collation(*arguments)
        configuration = arguments.first
        class_for_adapter(configuration['adapter']).new(*arguments).collation
      end

      def purge(configuration)
        class_for_adapter(configuration['adapter']).new(configuration).purge
      end

      def structure_dump(*arguments)
        configuration = arguments.first
        filename = arguments.delete_at 1
        class_for_adapter(configuration['adapter']).new(*arguments).structure_dump(filename)
      end

      def structure_load(*arguments)
        configuration = arguments.first
        filename = arguments.delete_at 1
        class_for_adapter(configuration['adapter']).new(*arguments).structure_load(filename)
      end

      def load_seed
        if seed_loader
          seed_loader.load_seed
        else
          raise "You tried to load seed data, but no seed loader is specified. Please specify seed " +
                "loader with ActiveRecord::Tasks::DatabaseTasks.seed_loader = your_seed_loader\n" +
                "Seed loader should respond to load_seed method"
        end
      end

      private

      def database_url_config
        @database_url_config ||=
               ConnectionAdapters::ConnectionSpecification::Resolver.new(ENV["DATABASE_URL"], {}).spec.config.stringify_keys
      end

      def class_for_adapter(adapter)
        key = @tasks.keys.detect { |pattern| adapter[pattern] }
        unless key
          raise DatabaseNotSupported, "Rake tasks not supported by '#{adapter}' adapter"
        end
        @tasks[key]
      end

      def each_current_configuration(environment)
        environments = [environment]
        environments << 'test' if environment == 'development'

        configurations = ActiveRecord::Base.configurations.values_at(*environments)
        configurations.compact.each do |configuration|
          yield configuration unless configuration['database'].blank?
        end
      end

      def each_local_configuration
        ActiveRecord::Base.configurations.each_value do |configuration|
          next unless configuration['database']

          if local_database?(configuration)
            yield configuration
          else
            $stderr.puts "This task only modifies local databases. #{configuration['database']} is on a remote host."
          end
        end
      end

      def local_database?(configuration)
        configuration['host'].blank? || LOCAL_HOSTS.include?(configuration['host'])
      end
    end
  end
end
