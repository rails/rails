module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Uuid < ActiveModel::Type::Value # :nodoc:
          ACCEPTABLE_UUID = %r{\A\{?([a-fA-F0-9]{4}-?){8}\}?\z}x

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
