# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class PoolManager # :nodoc:
      def initialize
        @name_to_pool_config = {}
      end

      def pool_configs
        @name_to_pool_config.values
      end

      def remove_pool_config(key)
        @name_to_pool_config.delete(key)
      end

      def get_pool_config(key)
        @name_to_pool_config[key]
      end

      def set_pool_config(key, pool_config)
        @name_to_pool_config[key] = pool_config
      end
    end
  end
end
