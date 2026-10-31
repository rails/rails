# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Macaddr < Type::String # :nodoc:
          def type
            :macaddr
          end

          def changed?(old_value, new_value, _new_value_before_type_cast)
            old_value.class != new_value.class ||
              new_value && old_value.casecmp(new_value) != 0
          end

          def changed_in_place?(raw_old_value, new_value)
            raw_old_value.class != new_value.class ||
              new_value && raw_old_value.casecmp(new_value) != 0
          end
        end
      end
    end
  end
end
