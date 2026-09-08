# frozen_string_literal: true

require "uri"
require "active_record/database_configurations/database_config"
require "active_record/database_configurations/hash_config"
require "active_record/database_configurations/url_config"
require "active_record/database_configurations/connection_url_resolver"

module ActiveRecord
  # = Active Record Database Configurations
  #
  # +ActiveRecord::DatabaseConfigurations+ returns an array of +DatabaseConfig+
  # objects that are constructed from the application's database
  # configuration hash or URL string.
  #
  # The array of +DatabaseConfig+ objects in an application default to either a
  # HashConfig or UrlConfig. You can retrieve your application's config by using
  # ActiveRecord::Base.configurations.
  #
  # If you register a custom handler, objects will be created according to the
  # conditions of the handler. See ::register_db_config_handler for more on
  # registering custom handlers.
  class DatabaseConfigurations
    class InvalidConfigurationError < StandardError; end

    attr_reader :configurations
    delegate :any?, to: :configurations

    singleton_class.attr_accessor :db_config_handlers # :nodoc:
    self.db_config_handlers = [] # :nodoc:

    # Allows an application to register a custom handler for database configuration
    # objects. This is useful for creating a custom handler that responds to
    # methods your application needs but Active Record doesn't implement. For
    # example if you are using Vitess, you may want your Vitess configurations
    # to respond to `sharded?`. To implement this define the following in an
    # initializer:
    #
    #   ActiveSupport.on_load(:active_record_database_configurations) do
    #     ActiveRecord::DatabaseConfigurations.register_db_config_handler do |env_name, name, url, config|
    #       next unless config.key?(:vitess)
    #       VitessConfig.new(env_name, name, config)
    #     end
    #   end
    #
    # Note: applications must handle the condition in which custom config should be
    # created in your handler registration otherwise all objects will use the custom
    # handler.
    #
    # Then define your +VitessConfig+ to respond to the methods your application
    # needs. It is recommended that you inherit from one of the existing
    # database config classes to avoid having to reimplement all methods. Custom
    # config handlers should only implement methods Active Record does not.
    #
    #   class VitessConfig < ActiveRecord::DatabaseConfigurations::UrlConfig
    #     def sharded?
    #       configuration_hash.fetch("sharded", false)
    #     end
    #   end
    #
    # For configs that have a +:vitess+ key, a +VitessConfig+ object will be
    # created instead of a +UrlConfig+.
    def self.register_db_config_handler(&block)
      db_config_handlers << block
    end

    register_db_config_handler do |env_name, name, url, config|
      if url
        UrlConfig.new(env_name, name, url, config)
      else
        HashConfig.new(env_name, name, config)
      end
    end

    def initialize(configurations = {})
      @configurations = build_configs(configurations)
    end

    # Collects the configs for the environment and optionally the specification
    # name passed in. To include replica configurations pass <tt>include_hidden: true</tt>.
    #
    # If a name is provided a single +DatabaseConfig+ object will be
    # returned, otherwise an array of +DatabaseConfig+ objects will be
    # returned that corresponds with the environment and type requested.
    #
    # ==== Options
    #
    # * <tt>env_name:</tt> The environment name. Defaults to +nil+ which will collect
    #   configs for all environments.
    # * <tt>name:</tt> The db config name (i.e. primary, animals, etc.). Defaults
    #   to +nil+. If no +env_name+ is specified the config for the default env and the
    #   passed +name+ will be returned.
    # * <tt>config_key:</tt> Selects configs that contain a particular key in the configuration
    #   hash. Useful for selecting configs that use a custom db config handler or finding
    #   configs with hashes that contain a particular key.
    # * <tt>include_hidden:</tt> Determines whether to include replicas and configurations
    #   hidden by <tt>database_tasks: false</tt> in the returned list. Most of the time we're only
    #   iterating over the primary connections (i.e. migrations don't need to run for the
    #   write and read connection). Defaults to +false+.
    def configs_for(env_name: nil, name: nil, config_key: nil, include_hidden: false)
      env_name ||= default_env if name
      configs = env_with_configs(env_name)

      unless include_hidden
        configs = configs.select do |db_config|
          db_config.database_tasks?
        end
      end

      if config_key
        configs = configs.select do |db_config|
          db_config.configuration_hash.key?(config_key)
        end
      end

      if name
        configs.find do |db_config|
          db_config.name == name.to_s
        end
      else
        configs
      end
    end

    # Returns a single +DatabaseConfig+ object based on the requested environment.
    #
    # If the application has multiple databases +find_db_config+ will return
    # the first +DatabaseConfig+ for the environment.
    def find_db_config(env)
      env = env.to_s
      configurations.find do |db_config|
        db_config.for_current_env? && (db_config.env_name == env || db_config.name == env)
      end || configurations.find do |db_config|
        db_config.env_name == env
      end
    end

    # A primary configuration is one that is named primary or if there is
    # no primary, the first configuration for an environment will be treated
    # as primary. This is used as the "default" configuration and is used
    # when the application needs to treat one configuration differently. For
    # example, when Rails dumps the schema, the primary configuration's schema
    # file will be named `schema.rb` instead of `primary_schema.rb`.
    def primary?(name) # :nodoc:
      return true if name == "primary"

      first_config = find_db_config(default_env)
      first_config && name == first_config.name
    end

    # Checks if the application's configurations are empty.
    def empty?
      configurations.empty?
    end
    alias :blank? :empty?

    # Returns fully resolved connection, accepts hash, string or symbol.
    # Always returns a DatabaseConfiguration::DatabaseConfig
    #
    # == Examples
    #
    # Symbol representing current environment.
    #
    #   DatabaseConfigurations.new("production" => {}).resolve(:production)
    #   # => DatabaseConfigurations::HashConfig.new(env_name: "production", config: {})
    #
    # One layer deep hash of connection values.
    #
    #   DatabaseConfigurations.new({}).resolve("adapter" => "sqlite3")
    #   # => DatabaseConfigurations::HashConfig.new(config: {"adapter" => "sqlite3"})
    #
    # Connection URL.
    #
    #   DatabaseConfigurations.new({}).resolve("postgresql://localhost/foo")
    #   # => DatabaseConfigurations::UrlConfig.new(config: {"adapter" => "postgresql", "host" => "localhost", "database" => "foo"})
    def resolve(config) # :nodoc:
      return config if DatabaseConfigurations::DatabaseConfig === config

      case config
      when Symbol
        resolve_symbol_connection(config)
      when Hash, String
        build_db_config_from_raw_config(default_env, "primary", config)
      else
        raise TypeError, "Invalid type for configuration. Expected Symbol, String, or Hash. Got #{config.inspect}"
      end
    end

    private
      def default_env
        ActiveRecord::ConnectionHandling::DEFAULT_ENV.call.to_s
      end

      def env_with_configs(env = nil)
        if env
          configurations.select { |db_config| db_config.env_name == env }
        else
          configurations
        end
      end

      def build_configs(configs)
        return configs.configurations if configs.is_a?(DatabaseConfigurations)
        return configs if configs.is_a?(Array)

        db_configs = configs.flat_map do |env_name, config|
          if config.is_a?(Hash) && config.values.all?(Hash)
            walk_configs(env_name.to_s, config)
          else
            build_db_config_from_raw_config(env_name.to_s, "primary", config)
          end
        end

        unless db_configs.find(&:for_current_env?)
          db_configs << environment_url_config(default_env, "primary", {})
        end

        merge_db_environment_variables(default_env, db_configs.compact)
      end

      def walk_configs(env_name, config)
        config.map do |name, sub_config|
          build_db_config_from_raw_config(env_name, name.to_s, sub_config)
        end
      end

      def resolve_symbol_connection(name)
        if db_config = find_db_config(name)
          db_config
        else
          raise AdapterNotSpecified, <<~MSG
            The `#{name}` database is not configured for the `#{default_env}` environment.

              Available database configurations are:

              #{build_configuration_sentence}
          MSG
        end
      end

      def build_configuration_sentence
        configs = configs_for(include_hidden: true)

        configs.group_by(&:env_name).map do |env, config|
          names = config.map(&:name)
          if names.size > 1
            "#{env}: #{names.join(", ")}"
          else
            env
          end
        end.join("\n")
      end

      def build_db_config_from_raw_config(env_name, name, config)
        case config
        when String
          build_db_config_from_string(env_name, name, config)
        when Hash
          build_db_config_from_hash(env_name, name, config.symbolize_keys)
        else
          raise InvalidConfigurationError, "'{ #{env_name} => #{config} }' is not a valid configuration. Expected '#{config}' to be a URL string or a Hash."
        end
      end

      def build_db_config_from_string(env_name, name, config)
        url = config
        uri = URI.parse(url)
        if uri.scheme
          UrlConfig.new(env_name, name, url)
        else
          raise InvalidConfigurationError, "'{ #{env_name} => #{config} }' is not a valid configuration. Expected '#{config}' to be a URL string or a Hash."
        end
      end

      def build_db_config_from_hash(env_name, name, config)
        url = config[:url]
        config_without_url = config.dup
        config_without_url.delete :url

        DatabaseConfigurations.db_config_handlers.reverse_each do |handler|
          config = handler.call(env_name, name, url, config_without_url)
          return config if config
        end

        nil
      end

      def merge_db_environment_variables(current_env, configs)
        configs.map do |config|
          next config if config.is_a?(UrlConfig) || config.env_name != current_env

          url_config = environment_url_config(current_env, config.name, config.configuration_hash)
          url_config || config
        end
      end

      def environment_url_config(env, name, config)
        url = environment_value_for(name)
        return unless url

        UrlConfig.new(env, name, url, config)
      end

      def environment_value_for(name)
        name_env_key = "#{name.upcase}_DATABASE_URL"
        url = ENV[name_env_key]
        url ||= ENV["DATABASE_URL"] if name == "primary"
        url
      end
  end

  ActiveSupport.run_load_hooks(:active_record_database_configurations, DatabaseConfigurations)
end
