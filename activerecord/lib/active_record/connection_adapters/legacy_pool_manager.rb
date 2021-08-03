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

      def set_pool_config(role, shard, pool_config)
        if pool_config
          @name_to_pool_config[shard] = pool_config
        else
          raise ArgumentError, "The `pool_config` for the :#{role} role and :#{shard} shard was `nil`. Please check your configuration. If you want your writing role to be something other than `:writing` set `config.active_record.writing_role` in your application configuration. The same setting should be applied for the `reading_role` if applicable."
        end
      end
    end
  end
end
