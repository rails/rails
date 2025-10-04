# frozen_string_literal: true

require "concurrent/map"

module ActiveRecord
  module Type
    class TypeMap # :nodoc:
      def initialize(parent = nil)
        @mapping = {}
        @parent = parent
        @cache = Concurrent::Map.new
      end

      def lookup(lookup_key)
        fetch(lookup_key) { Type.default_value }
      end

      def fetch(lookup_key, &block)
        @cache.fetch_or_store(lookup_key) do
          perform_fetch(lookup_key, &block)
        end
      end

      def register_type(key, value = nil, &block)
        raise ::ArgumentError unless value || block

        if block
          @mapping[key] = block
        else
          @mapping[key] = proc { value }
        end
        @cache.clear
      end

      def alias_type(key, target_key)
        register_type(key) do |sql_type|
          metadata = sql_type[/\(.*\)/, 0]
          lookup("#{target_key}#{metadata}")
        end
      end

      protected
        def perform_fetch(lookup_key, &block)
          matching_pair = @mapping.reverse_each.detect do |key, _|
            key === lookup_key
          end

          if matching_pair
            matching_pair.last.call(lookup_key).freeze
          elsif @parent
            @parent.perform_fetch(lookup_key, &block)
          else
            yield lookup_key
          end
        end
    end
  end
end
