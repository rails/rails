# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Date < Type::Date # :nodoc:
          def cast_value(value)
            case value
            when "infinity" then ::Float::INFINITY
            when "-infinity" then -::Float::INFINITY
            when / BC$/
              astronomical_year = format("%04d", -value[/^\d+/].to_i + 1)
              super(value.sub(/ BC$/, "").sub(/^\d+/, astronomical_year))
            else
              super
            end
          end
        end
      end
    end
  end
end
