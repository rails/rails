module ActiveRecord
  module Tasks # :nodoc:
    class DatabaseAlreadyExists < StandardError; end # :nodoc:
    class DatabaseNotSupported < StandardError; end # :nodoc:

    module DatabaseTasks # :nodoc:
      extend self

      attr_writer :current_config

      LOCAL_HOSTS    = ['127.0.0.1', 'localhost']

      def register_task(pattern, task)
        @tasks ||= {}
        @tasks[pattern] = task
      end

      register_task(/mysql/, ActiveRecord::Tasks::MySQLDatabaseTasks)
      register_task(/postgresql/, ActiveRecord::Tasks::PostgreSQLDatabaseTasks)
      register_task(/sqlite/, ActiveRecord::Tasks::SQLiteDatabaseTasks)

      def current_config(options = {})
        options.reverse_merge! :env => Rails.env
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

      def create_current(environment = Rails.env)
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

      def drop_current(environment = Rails.env)
        each_current_configuration(environment) { |configuration|
          drop configuration
        }
      end

      def drop_database_url
        drop database_url_config
      end

      def charset_current(environment = Rails.env)
        charset ActiveRecord::Base.configurations[environment]
      end

      def charset(*arguments)
        configuration = arguments.first
        class_for_adapter(configuration['adapter']).new(*arguments).charset
      end

      def collation_current(environment = Rails.env)
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
        environments << 'test' if environment.development?

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
