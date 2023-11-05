# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Uuid < Type::Value # :nodoc:
          ACCEPTABLE_UUID = %r{\A(\{)?([a-fA-F0-9]{4}-?){8}(?(1)\}|)\z}
          CANONICAL_UUID = %r{\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z}

          alias :serialize :deserialize

          def type
            :uuid
          end

          def changed?(old_value, new_value, _new_value_before_type_cast)
            old_value.class != new_value.class ||
              new_value != old_value
          end

          def changed_in_place?(raw_old_value, new_value)
            raw_old_value.class != new_value.class ||
              new_value != raw_old_value
          end

          private
            def cast_value(value)
              value = value.to_s
              format_uuid(value) if value.match?(ACCEPTABLE_UUID)
            end

            def format_uuid(uuid)
              if uuid.match?(CANONICAL_UUID)
                uuid
              else
                uuid = uuid.delete("{}-").downcase
                "#{uuid[..7]}-#{uuid[8..11]}-#{uuid[12..15]}-#{uuid[16..19]}-#{uuid[20..]}"
              end
            end
        end
      end
    end
  end
end
