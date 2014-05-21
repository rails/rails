module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Float < Type::Float
          include Infinity

          def type_cast(value)
            case value
            when nil then         nil
            when 'Infinity' then  ::Float::INFINITY
            when '-Infinity' then -::Float::INFINITY
            when 'NaN' then       ::Float::NAN
            else                  value.to_f
            end
          end
        end
      end
    end
  end
end
