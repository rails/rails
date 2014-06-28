module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Jsonb < Type::Value # :nodoc:
          include Type::Mutable

          def type
            :jsonb
          end

          def type_cast_from_database(value)
            ConnectionAdapters::PostgreSQLColumn.string_to_json(value)
          end

          def type_cast_for_database(value)
            ConnectionAdapters::PostgreSQLColumn.json_to_string(value)
          end

          def accessor
            ActiveRecord::Store::StringKeyedHashAccessor
          end

          def changed_in_place?(raw_old_value, new_value)
            # Postgresql returns json with a space before each key while JSON gem does not.
            raw_old_value = JSON.generate(JSON.parse(raw_old_value), quicks_mode: true) if raw_old_value
            raw_old_value != type_cast_for_database(new_value)
          end
        end
      end
    end
  end
end
