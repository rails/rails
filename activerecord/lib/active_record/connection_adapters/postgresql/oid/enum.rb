module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Enum < Type::Value # :nodoc:
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
