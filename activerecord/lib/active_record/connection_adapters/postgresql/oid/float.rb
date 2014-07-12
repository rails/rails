module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Float < Type::Float # :nodoc:
          include Infinity

          def cast_value(value)
            case value
            when ::Float then     value
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
