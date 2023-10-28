# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module Type # :nodoc:
        class Uuid < ActiveModel::Type::Value # :nodoc:
          ACCEPTABLE_UUID = /\A\h(-*\h-*){30}\h\z/

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
              value = value.to_s
              format_uuid(value) if value.match?(ACCEPTABLE_UUID)
            end

            def format_uuid(uuid)
              uuid = uuid.delete("-").downcase
              "#{uuid[..7]}-#{uuid[8..11]}-#{uuid[12..15]}-#{uuid[16..19]}-#{uuid[20..]}"
            end
        end
      end
    end
  end
end
