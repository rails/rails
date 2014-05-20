module ActiveRecord
  module ConnectionAdapters
    module Type
      class HashLookupTypeMap < TypeMap # :nodoc:
        def lookup(type)
          @mapping.fetch(type, proc { default_value }).call(type)
        end

        def alias_type(type, alias_type)
          register_type(type) { lookup(alias_type) }
        end
      end
    end
  end
end
