# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class PoolManager # :nodoc:
      def initialize
        @name_to_role_mapping = Hash.new { |h, k| h[k] = {} }
      end

      def shard_names
        @name_to_role_mapping.values.flat_map { |shard_map| shard_map.keys }
      end

      def role_names
        @name_to_role_mapping.keys
      end

      def pool_configs(role = nil)
        if role
          @name_to_role_mapping[role].values
        else
          @name_to_role_mapping.flat_map { |_, shard_map| shard_map.values }
        end
      end

      def remove_role(role)
        @name_to_role_mapping.delete(role)
      end

      def remove_pool_config(role, shard)
        @name_to_role_mapping[role].delete(shard)
      end

      def get_pool_config(role, shard)
        @name_to_role_mapping[role][shard]
      end

      def set_pool_config(role, shard, pool_config)
        @name_to_role_mapping[role][shard] = pool_config
      end
    end
  end
end
