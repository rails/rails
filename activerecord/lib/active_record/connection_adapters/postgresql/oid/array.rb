module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Array < Type::Value
          attr_reader :subtype
          delegate :type, to: :subtype

          def initialize(subtype)
            @subtype = subtype
          end

          def type_cast(value)
            if ::String === value
              ConnectionAdapters::PostgreSQLColumn.string_to_array value, @subtype
            else
              value
            end
          end
        end
      end
    end
  end
end
