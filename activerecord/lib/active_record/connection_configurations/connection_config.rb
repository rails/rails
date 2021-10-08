# frozen_string_literal: true

require "active_support/core_ext/hash/deep_transform_values"

module ActiveRecord
  class ConnectionConfigurations
    class ConnectionConfig # :nodoc:
      attr_reader :connection_config

      def initialize(config_hash)
        @connection_config = symbolize_hash_for_connects_to(config_hash)
      end

      private
        def symbolize_hash_for_connects_to(config_hash)
          if config_hash["database"] && config_hash["shards"]
            raise ArgumentError, "Connection configurations can only accept a `database` or `shards` argument, but not both arguments."
          end

          config_hash.deep_symbolize_keys.deep_transform_values!(&:to_sym)
        end
    end
  end
end
