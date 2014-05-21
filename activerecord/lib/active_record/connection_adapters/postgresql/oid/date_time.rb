module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class DateTime < Type::DateTime
          include Infinity

          def cast_value(value)
            if value.is_a?(::String)
              case value
              when 'infinity' then ::Float::INFINITY
              when '-infinity' then -::Float::INFINITY
              when / BC$/
                super("-" + value.sub(/ BC$/, ""))
              else
                super
              end
            else
              value
            end
          end
        end
      end
    end
  end
end
