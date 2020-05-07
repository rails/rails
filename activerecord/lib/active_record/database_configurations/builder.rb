# frozen_string_literal: true

require "active_record/database_configurations/builder/config"

module ActiveRecord
  class DatabaseConfigurations
    class Builder < BasicObject # :nodoc:
      attr_reader :configurations

      def initialize(dummy: false)
        @configurations = []
        @dummy = dummy
        @env_name = nil
      end

      def env(env_name)
        original_env_name = @env_name
        @env_name = env_name
        yield
      ensure
        @env_name = original_env_name
      end

      # Build a new config and add it to the configurations list
      def config(name, inherited_db_config = nil, &blk)
        config = Config.new(@env_name, name, [inherited_db_config].compact, false)
        config.evaluate(&blk) unless @dummy

        @configurations.concat config.db_configs
      end

      # Build a config to be used as a default for other configs
      def build(inherited_db_config = nil, &blk)
        return if @dummy

        config = Config.new(@env_name, nil, [inherited_db_config].compact, false)
        config.evaluate(&blk)
        config.db_configs.first
      end
    end
  end
end
