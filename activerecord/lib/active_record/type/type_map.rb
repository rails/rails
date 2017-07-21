# frozen_string_literal: true

require "concurrent/map"

module ActiveRecord
  module Type
    class TypeMap # :nodoc:
      def initialize
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
        @cache.clear

        if block
          @mapping[key] = block
        else
          @mapping[key] = proc { value }
        end
      end

      def alias_type(key, target_key)
        register_type(key) do |sql_type, *args|
          metadata = sql_type[/\(.*\)/, 0]
          lookup("#{target_key}#{metadata}", *args)
        end
      end

      def clear
        @mapping.clear
      end

      private

        def perform_fetch(lookup_key, *args)
          matching_pair = @mapping.reverse_each.detect do |key, _|
            key === lookup_key
          end

          if matching_pair
            matching_pair.last.call(lookup_key, *args)
          else
            yield lookup_key, *args
          end
        end
    end
  end
end
