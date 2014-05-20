module ActiveRecord
  module ConnectionAdapters
    module Type
      class HashLookupTypeMap < TypeMap # :nodoc:
        delegate :key?, to: :@mapping

        def lookup(type)
          @mapping.fetch(type, proc { default_value }).call(type)
        end

        def fetch(type, &block)
          @mapping.fetch(type, block).call(type)
        end

        def alias_type(type, alias_type)
          register_type(type) { lookup(alias_type) }
        end
      end
    end
  end
end
