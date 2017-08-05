# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Enum < Type::Value # :nodoc:
          def type
            :enum
          end

          private

            def cast_value(value)
              value.to_s
            end
        end
      end
    end
  end
end
