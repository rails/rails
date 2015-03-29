module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Box < Type::Value # :nodoc:
          def type
            :box
          end

          def serialize(value)
            if value.is_a?(::Array)
              "(#{serialize(value[0])},#{serialize(value[1])})"
            else
              value
            end
          end

          def cast(value)
            case value
            when ::String
              values = value.tr('()', '').split(',')
              if values
                values = values.map{|v| Float(v)}
                [[values[0], values[1]], [values[2], values[3]]]
              else
                value
              end
            else
              value
            end
          end

          def changed_in_place?(raw_old_value, new_value)
            cast(raw_old_value) != new_value
          end
        end
      end
    end
  end
end
