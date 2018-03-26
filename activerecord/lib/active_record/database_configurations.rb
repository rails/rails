# frozen_string_literal: true

module ActiveRecord
  module DatabaseConfigurations # :nodoc:
    class DatabaseConfig
      attr_reader :env_name, :spec_name, :config

      def initialize(env_name, spec_name, config)
        @env_name = env_name
        @spec_name = spec_name
        @config = config
      end
    end

    # Selects the config for the specified environment and specification name
    #
    # For example if passed :development, and :animals it will select the database
    # under the :development and :animals configuration level
    def self.config_for_env_and_spec(environment, specification_name, configs = ActiveRecord::Base.configurations) # :nodoc:
      configs_for(environment, configs).find do |db_config|
        db_config.spec_name == specification_name
      end
    end

    # Collects the configs for the environment passed in.
    #
    # If a block is given returns the specification name and configuration
    # otherwise returns an array of DatabaseConfig structs for the environment.
    def self.configs_for(env, configs = ActiveRecord::Base.configurations, &blk) # :nodoc:
      env_with_configs = db_configs(configs).select do |db_config|
        db_config.env_name == env
      end

      if block_given?
        env_with_configs.each do |env_with_config|
          yield env_with_config.spec_name, env_with_config.config
        end
      else
        env_with_configs
      end
    end

    # Given an env, spec and config creates DatabaseConfig structs with
    # each attribute set.
    def self.walk_configs(env_name, spec_name, config) # :nodoc:
      if config["database"] || env_name == "default"
        DatabaseConfig.new(env_name, spec_name, config)
      else
        config.each_pair.map do |spec_name, sub_config|
          walk_configs(env_name, spec_name, sub_config)
        end
      end
    end

    # Walks all the configs passed in and returns an array
    # of DatabaseConfig structs for each configuration.
    def self.db_configs(configs = ActiveRecord::Base.configurations) # :nodoc:
      configs.each_pair.flat_map do |env_name, config|
        walk_configs(env_name, "primary", config)
      end
    end
  end
end
