# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Uuid < Type::Value # :nodoc:
          ACCEPTABLE_UUID = %r{\A(\{)?([a-fA-F0-9]{4}-?){8}(?(1)\}|)\z}

          alias_method :serialize, :deserialize

          def type
            :uuid
          end

          def cast(value)
            value.to_s[ACCEPTABLE_UUID, 0]
          end
        end
      end
    end
  end
end
