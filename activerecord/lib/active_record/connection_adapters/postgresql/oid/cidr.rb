module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Cidr < Type::Value
          def type
            :cidr
          end

          def cast_value(value)
            ConnectionAdapters::PostgreSQLColumn.string_to_cidr value
          end
        end
      end
    end
  end
end
