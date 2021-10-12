# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Uuid < Type::Value # :nodoc:
          ACCEPTABLE_UUID = %r{\A(\{)?([a-fA-F0-9]{4}-?){8}(?(1)\}|)\z}

          alias :serialize :deserialize

          def type
            :uuid
          end

          def changed?(old_value, new_value, _new_value_before_type_cast)
            old_value.class != new_value.class ||
              new_value && old_value.casecmp(new_value) != 0
          end

          def changed_in_place?(raw_old_value, new_value)
            raw_old_value.class != new_value.class ||
              new_value && raw_old_value.casecmp(new_value) != 0
          end

          private
            def cast_value(value)
              casted = value.to_s
              casted if casted.match?(ACCEPTABLE_UUID)
            end
        end
      end
    end
  end
end
