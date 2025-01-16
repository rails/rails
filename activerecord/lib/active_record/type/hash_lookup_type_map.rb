# frozen_string_literal: true

module ActiveRecord
  module Type
    class HashLookupTypeMap # :nodoc:
      def initialize(parent = nil)
        @mapping = {}
        @cache = Concurrent::Map.new do |h, key|
          h.fetch_or_store(key, Concurrent::Map.new)
        end
      end

      def lookup(lookup_key, *args)
        fetch(lookup_key, *args) { Type.default_value }
      end

      def fetch(lookup_key, *args, &block)
        @cache[lookup_key].fetch_or_store(args) do
          perform_fetch(lookup_key, *args, &block)
        end
      end

      def register_type(key, value = nil, &block)
        raise ::ArgumentError unless value || block

        if block
          @mapping[key] = block
        else
          value.freeze
          @mapping[key] = proc { value }
        end
        @cache.clear
      end

      def clear
        @mapping.clear
        @cache.clear
      end

      def alias_type(type, alias_type)
        register_type(type) { |_, *args| lookup(alias_type, *args) }
      end

      def key?(key)
        @mapping.key?(key)
      end

      def keys
        @mapping.keys
      end

      private
        def perform_fetch(type, *args, &block)
          @mapping.fetch(type, block).call(type, *args).freeze
        end
    end
  end
end
