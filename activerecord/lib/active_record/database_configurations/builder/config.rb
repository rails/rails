# frozen_string_literal: true

require "active_record/database_configurations/builder/block_context"

module ActiveRecord
  class DatabaseConfigurations
    class Builder < BasicObject
      class Config # :nodoc:
        def initialize(env_name, name, default_db_configs, replica)
          @env_name = env_name.to_s
          @name = name.to_s

          @block_context = BlockContext.new(self, build_hash(default_db_configs, replica))

          @subconfigs = []
        end

        def shard(subname, default_db_config = nil, &blk)
          add_subconfig("shard_#{subname}", default_db_config, false, &blk)
        end

        def replica(suffix = nil, default_db_config = nil, &blk)
          name_suffix = suffix ? "replica_#{suffix}" : "replica"
          add_subconfig(name_suffix, default_db_config, true, &blk)
        end

        def evaluate(&blk)
          @block_context.instance_eval(&blk)
        end

        def db_configs
          configs = [build_db_config]
          configs.concat(@subconfigs.flat_map(&:db_configs))
          configs
        end

        private
          def add_subconfig(name_suffix, default_db_config, replica, &blk)
            name = [@name, name_suffix].join("_")

            default_db_configs = [build_db_config]
            default_db_configs << default_db_config if default_db_config

            subconfig = Config.new(@env_name, name, default_db_configs, replica)
            subconfig.evaluate(&blk) if block_given?

            @subconfigs << subconfig
          end

          def build_db_config
            hash = @block_context.hash
            if hash.has_key?(:url)
              config_without_url = hash.dup
              url = config_without_url.delete :url

              UrlConfig.new(@env_name, @name, url, config_without_url)
            else
              HashConfig.new(@env_name, @name, hash)
            end
          end

          def build_hash(default_db_configs, replica)
            hash = {}

            default_db_configs.each do |db_config|
              hash.merge!(db_config.configuration_hash)
            end

            hash[:replica] = true if replica

            hash
          end
      end
    end
  end
end
