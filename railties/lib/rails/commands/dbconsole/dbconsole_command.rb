# frozen_string_literal: true

require "active_support/core_ext/string/filters"
require "rails/command/environment_argument"

module Rails
  class DBConsole
    def self.start(*args)
      new(*args).start
    end

    def initialize(options = {})
      @options = options
      @options[:environment] ||= Rails::Command.environment
    end

    def start
      adapter_class.dbconsole(db_config, @options)
    rescue NotImplementedError, ActiveRecord::AdapterNotFound, LoadError => error
      abort error.message
    end

    def db_config
      @db_config ||= begin
        # If the user provided a database, use that. Otherwise find
        # the first config in the database.yml
        config = if database
          @db_config = configurations.configs_for(env_name: environment, name: database, include_hidden: true)
        else
          @db_config = configurations.find_db_config(environment)
        end

        unless config
          missing_db = database ? "'#{database}' database is not" : "No databases are"
          raise ActiveRecord::AdapterNotSpecified,
            "#{missing_db} configured for '#{environment}'. Available configuration: #{configurations.inspect}"
        end

        config.validate!
        config
      end
    end

    def database
      @options[:database]
    end

    def environment
      @options[:environment]
    end

    private
      def adapter_class
        ActiveRecord::ConnectionAdapters.resolve(db_config.adapter)
      rescue LoadError
        ActiveRecord::ConnectionAdapters::AbstractAdapter
      end

      def configurations # :doc:
        require APP_PATH
        ActiveRecord::Base.configurations = Rails.application.config.database_configuration
        ActiveRecord::Base.configurations
      end
  end

  module Command
    class DbconsoleCommand < Base # :nodoc:
      include EnvironmentArgument

      class_option :include_password, aliases: "-p", type: :boolean,
        desc: "Automatically provide the password from database.yml"

      class_option :mode, enum: %w( html list line column ), type: :string,
        desc: "Automatically put the sqlite3 database in the specified mode"

      class_option :header, type: :boolean

      class_option :database, aliases: "--db", type: :string,
        desc: "Specify the database to use."

      desc "dbconsole", "Start a console for the database specified in config/database.yml"
      def perform
        boot_application!
        Rails::DBConsole.start(options)
      end
    end
  end
end
