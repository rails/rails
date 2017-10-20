# frozen_string_literal: true

module ActiveRecord
  module Type
    class HashLookupTypeMap < TypeMap # :nodoc:
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
          @mapping.fetch(type, block).call(type, *args)
        end
    end
  end
end
