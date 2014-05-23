module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Point < Type::String
          def type_cast(value)
            if ::String === value
              if value[0] == '(' && value[-1] == ')'
                value = value[1...-1]
              end
              value.split(',').map{ |v| Float(v) }
            else
              value
            end
          end
        end
      end
    end
  end
end
