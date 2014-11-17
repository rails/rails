module ActiveRecord
  module Type
    class HashLookupTypeMap < TypeMap # :nodoc:

      def initialize
        @cache = {}
        super
      end

      delegate :key?, to: :@mapping

      def lookup(type, *args)
        @mapping.fetch(type, proc { default_value }).call(type, *args)
      end

      def fetch(type, *args, &block)
        cache = (@cache[type] ||= {})
        resolved = cache[args]

        unless resolved
          resolved = cache[args] = @mapping.fetch(type, block).call(type, *args)
        end

        resolved
      end

      def alias_type(type, alias_type)
        register_type(type) { |_, *args| lookup(alias_type, *args) }
      end

      def register_type(key, value=nil, &block)
        @cache = {}
        super(key, value, &block)
      end
    end
  end
end
