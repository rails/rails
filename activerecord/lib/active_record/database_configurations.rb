# frozen_string_literal: true

require "active_record/database_configurations/database_config"
require "active_record/database_configurations/hash_config"
require "active_record/database_configurations/url_config"

module ActiveRecord
  # ActiveRecord::DatabaseConfigurations returns an array of DatabaseConfig
  # objects (either a HashConfig or UrlConfig) that are constructed from the
  # application's database configuration hash or URL string.
  class DatabaseConfigurations
    class InvalidConfigurationError < StandardError; end

    attr_reader :configurations
    delegate :any?, to: :configurations

    def initialize(configurations = {})
      @configurations = build_configs(configurations)
    end

    # Collects the configs for the environment and optionally the specification
    # name passed in. To include replica configurations pass <tt>include_replicas: true</tt>.
    #
    # If a spec name is provided a single DatabaseConfig object will be
    # returned, otherwise an array of DatabaseConfig objects will be
    # returned that corresponds with the environment and type requested.
    #
    # ==== Options
    #
    # * <tt>env_name:</tt> The environment name. Defaults to +nil+ which will collect
    #   configs for all environments.
    # * <tt>spec_name:</tt> The specification name (i.e. primary, animals, etc.). Defaults
    #   to +nil+.
    # * <tt>include_replicas:</tt> Determines whether to include replicas in
    #   the returned list. Most of the time we're only iterating over the write
    #   connection (i.e. migrations don't need to run for the write and read connection).
    #   Defaults to +false+.
    def configs_for(env_name: nil, spec_name: nil, include_replicas: false)
      configs = env_with_configs(env_name)

      unless include_replicas
        configs = configs.select do |db_config|
          !db_config.replica?
        end
      end

      if spec_name
        configs.find do |db_config|
          db_config.spec_name == spec_name
        end
      else
        configs
      end
    end

    # Returns the config hash that corresponds with the environment
    #
    # If the application has multiple databases +default_hash+ will
    # return the first config hash for the environment.
    #
    #   { database: "my_db", adapter: "mysql2" }
    def default_hash(env = ActiveRecord::ConnectionHandling::DEFAULT_ENV.call.to_s)
      default = find_db_config(env)
      default.config if default
    end
    alias :[] :default_hash

    # Returns a single DatabaseConfig object based on the requested environment.
    #
    # If the application has multiple databases +find_db_config+ will return
    # the first DatabaseConfig for the environment.
    def find_db_config(env)
      configurations.find do |db_config|
        db_config.env_name == env.to_s ||
          (db_config.for_current_env? && db_config.spec_name == env.to_s)
      end
    end

    # Returns the DatabaseConfigurations object as a Hash.
    def to_h
      configs = configurations.reverse.inject({}) do |memo, db_config|
        memo.merge(db_config.to_legacy_hash)
      end

      Hash[configs.to_a.reverse]
    end

    # Checks if the application's configurations are empty.
    #
    # Aliased to blank?
    def empty?
      configurations.empty?
    end
    alias :blank? :empty?

    def each
      throw_getter_deprecation(:each)
      configurations.each { |config|
        yield [config.env_name, config.config]
      }
    end

    def first
      throw_getter_deprecation(:first)
      config = configurations.first
      [config.env_name, config.config]
    end

    private
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
          if config.is_a?(Hash) && config.all? { |_, v| v.is_a?(Hash) }
            walk_configs(env_name.to_s, config)
          else
            build_db_config_from_raw_config(env_name.to_s, "primary", config)
          end
        end

        current_env = ActiveRecord::ConnectionHandling::DEFAULT_ENV.call.to_s

        unless db_configs.find(&:for_current_env?)
          db_configs << environment_url_config(current_env, "primary", {})
        end

        merge_db_environment_variables(current_env, db_configs.compact)
      end

      def walk_configs(env_name, config)
        config.map do |spec_name, sub_config|
          build_db_config_from_raw_config(env_name, spec_name.to_s, sub_config)
        end
      end

      def build_db_config_from_raw_config(env_name, spec_name, config)
        case config
        when String
          build_db_config_from_string(env_name, spec_name, config)
        when Hash
          build_db_config_from_hash(env_name, spec_name, config.stringify_keys)
        else
          raise InvalidConfigurationError, "'{ #{env_name} => #{config} }' is not a valid configuration. Expected '#{config}' to be a URL string or a Hash."
        end
      end

      def build_db_config_from_string(env_name, spec_name, config)
        url = config
        uri = URI.parse(url)
        if uri.scheme
          ActiveRecord::DatabaseConfigurations::UrlConfig.new(env_name, spec_name, url)
        else
          raise InvalidConfigurationError, "'{ #{env_name} => #{config} }' is not a valid configuration. Expected '#{config}' to be a URL string or a Hash."
        end
      end

      def build_db_config_from_hash(env_name, spec_name, config)
        if config.has_key?("url")
          url = config["url"]
          config_without_url = config.dup
          config_without_url.delete "url"

          ActiveRecord::DatabaseConfigurations::UrlConfig.new(env_name, spec_name, url, config_without_url)
        else
          ActiveRecord::DatabaseConfigurations::HashConfig.new(env_name, spec_name, config)
        end
      end

      def merge_db_environment_variables(current_env, configs)
        configs.map do |config|
          next config if config.url_config? || config.env_name != current_env

          url_config = environment_url_config(current_env, config.spec_name, config.config)
          url_config || config
        end
      end

      def environment_url_config(env, spec_name, config)
        url = environment_value_for(spec_name)
        return unless url

        ActiveRecord::DatabaseConfigurations::UrlConfig.new(env, spec_name, url, config)
      end

      def environment_value_for(spec_name)
        spec_env_key = "#{spec_name.upcase}_DATABASE_URL"
        url = ENV[spec_env_key]
        url ||= ENV["DATABASE_URL"] if spec_name == "primary"
        url
      end

      def method_missing(method, *args, &blk)
        case method
        when :fetch
          throw_getter_deprecation(method)
          configs_for(env_name: args.first)
        when :values
          throw_getter_deprecation(method)
          configurations.map(&:config)
        when :[]=
          throw_setter_deprecation(method)

          env_name = args[0]
          config = args[1]

          remaining_configs = configurations.reject { |db_config| db_config.env_name == env_name }
          new_config = build_configs(env_name => config)
          new_configs = remaining_configs + new_config

          ActiveRecord::Base.configurations = new_configs
        else
          raise NotImplementedError, "`ActiveRecord::Base.configurations` in Rails 6 now returns an object instead of a hash. The `#{method}` method is not supported. Please use `configs_for` or consult the documentation for supported methods."
        end
      end

      def throw_setter_deprecation(method)
        ActiveSupport::Deprecation.warn("Setting `ActiveRecord::Base.configurations` with `#{method}` is deprecated. Use `ActiveRecord::Base.configurations=` directly to set the configurations instead.")
      end

      def throw_getter_deprecation(method)
        ActiveSupport::Deprecation.warn("`ActiveRecord::Base.configurations` no longer returns a hash. Methods that act on the hash like `#{method}` are deprecated and will be removed in Rails 6.1. Use the `configs_for` method to collect and iterate over the database configurations.")
      end
  end
end
