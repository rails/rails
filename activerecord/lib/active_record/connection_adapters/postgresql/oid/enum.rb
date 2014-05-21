module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Enum < Type::Value
          def type
            :enum
          end

          def type_cast(value)
            value.to_s
          end
        end
      end
    end
  end
end
