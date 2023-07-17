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
    rescue NotImplementedError
      abort "Unknown command-line client for #{db_config.database}."
    end

    def db_config
      return @db_config if defined?(@db_config)

      # If the user provided a database, use that. Otherwise find
      # the first config in the database.yml
      if database
        @db_config = configurations.configs_for(env_name: environment, name: database, include_hidden: true)
      else
        @db_config = configurations.find_db_config(environment)
      end

      unless @db_config
        missing_db = database ? "'#{database}' database is not" : "No databases are"
        raise ActiveRecord::AdapterNotSpecified,
          "#{missing_db} configured for '#{environment}'. Available configuration: #{configurations.inspect}"
      end

      @db_config
    end

    def database
      @options[:database]
    end

    def environment
      @options[:environment]
    end

    private
      def adapter_class
        if ActiveRecord::Base.respond_to?(db_config.adapter_class_method)
          ActiveRecord::Base.public_send(db_config.adapter_class_method)
        else
          ActiveRecord::ConnectionAdapters::AbstractAdapter
        end
      end

      def configurations # :doc:
        require APP_PATH
        ActiveRecord::Base.configurations = Rails.application.config.database_configuration
        ActiveRecord::Base.configurations
      end

      def find_cmd_and_exec(commands, *args) # :doc:
        Rails.deprecator.warn(<<~MSG.squish)
          Rails::DBConsole#find_cmd_and_exec is deprecated and will be removed in Rails 7.2.
          Please use find_cmd_and_exec on the connection adapter class instead.
        MSG
        ActiveRecord::Base.connection.find_cmd_and_exec(commands, *args)
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
