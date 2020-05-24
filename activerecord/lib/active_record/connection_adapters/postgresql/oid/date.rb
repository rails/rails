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
              value = value.sub(/^\d+/) { |year| format("%04d", -year.to_i + 1) }
              super(value.delete_suffix!(" BC"))
            else
              super
            end
          end
        end
      end
    end
  end
end
