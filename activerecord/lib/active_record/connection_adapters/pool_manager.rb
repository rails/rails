# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class PoolManager # :nodoc:
      def initialize
        @role_to_shard_mapping = Hash.new { |h, k| h[k] = {} }
      end

      def shard_names
        @role_to_shard_mapping.values.flat_map { |shard_map| shard_map.keys }
      end

      def role_names
        @role_to_shard_mapping.keys
      end

      def pool_configs(role = nil)
        if role
          @role_to_shard_mapping[role].values
        else
          @role_to_shard_mapping.flat_map { |_, shard_map| shard_map.values }
        end
      end

      def each_pool_config(role = nil, &block)
        if role
          @role_to_shard_mapping[role].each_value(&block)
        else
          @role_to_shard_mapping.each_value do |shard_map|
            shard_map.each_value(&block)
          end
        end
      end

      def remove_role(role)
        @role_to_shard_mapping.delete(role)
      end

      def remove_pool_config(role, shard)
        @role_to_shard_mapping[role].delete(shard)
      end

      def get_pool_config(role, shard)
        @role_to_shard_mapping[role][shard]
      end

      def set_pool_config(role, shard, pool_config)
        if pool_config
          @role_to_shard_mapping[role][shard] = pool_config
        else
          raise ArgumentError, "The `pool_config` for the :#{role} role and :#{shard} shard was `nil`. Please check your configuration. If you want your writing role to be something other than `:writing` set `config.active_record.writing_role` in your application configuration. The same setting should be applied for the `reading_role` if applicable."
        end
      end
    end
  end
end
