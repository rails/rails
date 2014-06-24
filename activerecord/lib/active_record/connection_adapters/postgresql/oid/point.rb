module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Point < Type::Value # :nodoc:
          include Type::Mutable

          def type
            :point
          end

          def type_cast(value)
            case value
            when ::String
              if value[0] == '(' && value[-1] == ')'
                value = value[1...-1]
              end
              type_cast(value.split(','))
            when ::Array
              value.map { |v| Float(v) }
            else
              value
            end
          end

          def type_cast_for_database(value)
            if value.is_a?(::Array)
              PostgreSQLColumn.point_to_string(value)
            else
              super
            end
          end
        end
      end
    end
  end
end
