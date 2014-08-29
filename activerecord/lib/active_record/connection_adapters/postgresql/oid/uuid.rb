module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Uuid < Type::Value # :nodoc:
          RFC_4122 = %r{\A\{?[a-fA-F0-9]{4}-?
                             [a-fA-F0-9]{4}-?
                             [a-fA-F0-9]{4}-?
                             [1-5][a-fA-F0-9]{3}-?
                             [8-Bab][a-fA-F0-9]{3}-?
                             [a-fA-F0-9]{4}-?
                             [a-fA-F0-9]{4}-?
                             [a-fA-F0-9]{4}-?\}?\z}x

          alias_method :type_cast_for_database, :type_cast_from_database

          def type
            :uuid
          end

          def type_cast(value)
            value.to_s[RFC_4122, 0]
          end
        end
      end
    end
  end
end
