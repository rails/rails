module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class DateTime < Type::DateTime # :nodoc:
          include Infinity

          def type_cast_for_database(value)
            if has_precision? && value.acts_like?(:time) && value.year <= 0
              bce_year = format("%04d", -value.year + 1)
              super.sub(/^-?\d+/, bce_year) + " BC"
            else
              super
            end
          end

          def cast_value(value)
            if value.is_a?(::String)
              case value
              when 'infinity' then ::Float::INFINITY
              when '-infinity' then -::Float::INFINITY
              when / BC$/
                astronomical_year = format("%04d", -value[/^\d+/].to_i + 1)
                super(value.sub(/ BC$/, "").sub(/^\d+/, astronomical_year))
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
