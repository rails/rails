# frozen_string_literal: true

require "active_record/database_configurations/database_config"
require "active_record/database_configurations/hash_config"
require "active_record/database_configurations/url_config"

module ActiveRecord
  # ActiveRecord::DatabaseConfigurations returns an array of DatabaseConfig
  # objects (either a HashConfig or UrlConfig) that are constructed from the
  # application's database configuration hash or url string.
  class DatabaseConfigurations
    attr_reader :configurations
    delegate :any?, to: :configurations

    def initialize(configurations = {})
      @configurations = build_configs(configurations)
    end

    # Collects the configs for the environment and optionally the specification
    # name passed in. To include replica configurations pass `include_replicas: true`.
    #
    # If a spec name is provided a single DatabaseConfig object will be
    # returned, otherwise an array of DatabaseConfig objects will be
    # returned that corresponds with the environment and type requested.
    #
    # Options:
    #
    # <tt>env_name:</tt> The environment name. Defaults to nil which will collect
    # configs for all environments.
    # <tt>spec_name:</tt> The specification name (ie primary, animals, etc.). Defaults
    # to +nil+.
    # <tt>include_replicas:</tt> Determines whether to include replicas in the
    # the returned list. Most of the time we're only iterating over the write
    # connection (i.e. migrations don't need to run for the write and read connection).
    # Defaults to +false+.
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
    # If the application has multiple databases `default_hash` will
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
    # If the application has multiple databases `find_db_config` will return
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

        build_db_config = configs.each_pair.flat_map do |env_name, config|
          walk_configs(env_name.to_s, "primary", config)
        end.compact

        if url = ENV["DATABASE_URL"]
          build_url_config(url, build_db_config)
        else
          build_db_config
        end
      end

      def walk_configs(env_name, spec_name, config)
        case config
        when String
          build_db_config_from_string(env_name, spec_name, config)
        when Hash
          build_db_config_from_hash(env_name, spec_name, config.stringify_keys)
        end
      end

      def build_db_config_from_string(env_name, spec_name, config)
        begin
          url = config
          uri = URI.parse(url)
          if uri.try(:scheme)
            ActiveRecord::DatabaseConfigurations::UrlConfig.new(env_name, spec_name, url)
          end
        rescue URI::InvalidURIError
          ActiveRecord::DatabaseConfigurations::HashConfig.new(env_name, spec_name, config)
        end
      end

      def build_db_config_from_hash(env_name, spec_name, config)
        if url = config["url"]
          config_without_url = config.dup
          config_without_url.delete "url"
          ActiveRecord::DatabaseConfigurations::UrlConfig.new(env_name, spec_name, url, config_without_url)
        elsif config["database"] || (config.size == 1 && config.values.all? { |v| v.is_a? String })
          ActiveRecord::DatabaseConfigurations::HashConfig.new(env_name, spec_name, config)
        else
          config.each_pair.map do |sub_spec_name, sub_config|
            walk_configs(env_name, sub_spec_name, sub_config)
          end
        end
      end

      def build_url_config(url, configs)
        env = ActiveRecord::ConnectionHandling::DEFAULT_ENV.call.to_s

        if original_config = configs.find(&:for_current_env?)
          if original_config.url_config?
            configs
          else
            configs.map do |config|
              ActiveRecord::DatabaseConfigurations::UrlConfig.new(env, config.spec_name, url, config.config)
            end
          end
        else
          configs + [ActiveRecord::DatabaseConfigurations::UrlConfig.new(env, "primary", url)]
        end
      end

      def method_missing(method, *args, &blk)
        if Hash.method_defined?(method)
          ActiveSupport::Deprecation.warn \
            "Returning a hash from ActiveRecord::Base.configurations is deprecated. Therefore calling `#{method}` on the hash is also deprecated. Please switch to using the `configs_for` method instead to collect and iterate over database configurations."
        end

        case method
        when :each, :first
          configurations.send(method, *args, &blk)
        when :fetch
          configs_for(env_name: args.first)
        when :values
          configurations.map(&:config)
        else
          super
        end
      end
  end
end
