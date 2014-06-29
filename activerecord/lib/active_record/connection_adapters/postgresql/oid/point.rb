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
              "(#{number_for_point(value[0])},#{number_for_point(value[1])})"
            else
              super
            end
          end

          private

          def number_for_point(number)
            number.to_s.gsub(/\.0$/, '')
          end
        end
      end
    end
  end
end
