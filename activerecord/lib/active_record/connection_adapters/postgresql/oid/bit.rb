module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Bit < Type::String
          def type_cast(value)
            if ::String === value
              ConnectionAdapters::PostgreSQLColumn.string_to_bit value
            else
              value
            end
          end
        end
      end
    end
  end
end
