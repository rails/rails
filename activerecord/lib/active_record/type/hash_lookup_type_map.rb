module ActiveRecord
  module Type
    class HashLookupTypeMap < TypeMap # :nodoc:
      delegate :key?, to: :@mapping

      def alias_type(type, alias_type)
        register_type(type) { |_, *args| lookup(alias_type, *args) }
      end

      private

      def perform_fetch(type, *args, &block)
        @mapping.fetch(type, block).call(type, *args)
      end
    end
  end
end
