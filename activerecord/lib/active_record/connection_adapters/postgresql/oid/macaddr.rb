# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Macaddr < Type::String # :nodoc:
          def type
            :macaddr
          end

          private
            def cast_value(value)
              value.to_s.downcase
            end
        end
      end
    end
  end
end
