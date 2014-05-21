module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Point < Type::String
          def type_cast(value)
            if ::String === value
              ConnectionAdapters::PostgreSQLColumn.string_to_point value
            else
              value
            end
          end
        end
      end
    end
  end
end
