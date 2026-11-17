# frozen_string_literal: true

module ActiveRecord
  module Type
    class HashLookupTypeMap # :nodoc:
      def initialize
        @mapping = {}
        @cache = Concurrent::Map.new do |h, key|
          h.fetch_or_store(key, Concurrent::Map.new)
        end
        @result_type_keys = Concurrent::Map.new
      end

      def lookup(lookup_key, *args)
        fetch(lookup_key, *args) { Type.default_value }
      end

      def fetch(lookup_key, *args, &block)
        @cache[lookup_key].fetch_or_store(args) do
          perform_fetch(lookup_key, *args, &block)
        end
      end

      # Same as <tt>fetch(lookup_key, modifier, "")</tt>, for lookups without a
      # SQL type, such as PostgreSQL result columns. The <tt>[modifier, ""]</tt>
      # cache key is reused once a type was cached under it, instead of a new
      # Array on every call, and dropped with the cached types (#register_type,
      # #clear).
      def fetch_result_type(lookup_key, modifier, &block)
        unless args = @result_type_keys[modifier]
          args = [modifier, ""].freeze
          new_key = true
        end

        type = @cache[lookup_key].fetch_or_store(args) do
          perform_fetch(lookup_key, *args, &block)
        end
        # Only after the type was cached, so failed lookups retain nothing.
        @result_type_keys.put_if_absent(modifier, args) if new_key
        type
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
        @result_type_keys.clear
      end

      def clear
        @mapping.clear
        @cache.clear
        @result_type_keys.clear
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
