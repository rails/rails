module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Date < Type::Date # :nodoc:
          def cast_value(value)
            if value.is_a?(::String)
              case value
              when 'infinity' then ::Float::INFINITY
              when '-infinity' then -::Float::INFINITY
              else
                super
              end
            else
              super
            end
          end
        end
      end
    end
  end
end
