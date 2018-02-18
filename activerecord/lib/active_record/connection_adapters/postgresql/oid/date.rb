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
            else
              super
            end
          end
        end
      end
    end
  end
end
