# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class LegacyPoolManager # :nodoc:
      def initialize
        @name_to_pool_config = {}
      end

      def shard_names
        @name_to_pool_config.keys
      end

      def pool_configs(_ = nil)
        @name_to_pool_config.values
      end

      def remove_pool_config(_, shard)
        @name_to_pool_config.delete(shard)
      end

      def get_pool_config(_, shard)
        @name_to_pool_config[shard]
      end

      def set_pool_config(_, shard, pool_config)
        @name_to_pool_config[shard] = pool_config
      end
    end
  end
end
