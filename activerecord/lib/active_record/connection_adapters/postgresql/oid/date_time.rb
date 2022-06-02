# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class DateTime < Type::DateTime # :nodoc:
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

          def type_cast_for_schema(value)
            case value
            when ::Float::INFINITY then "::Float::INFINITY"
            when -::Float::INFINITY then "-::Float::INFINITY"
            else super
            end
          end

          protected
            def real_type_unless_aliased(real_type)
              ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type == real_type ? :datetime : real_type
            end
        end
      end
    end
  end
end
