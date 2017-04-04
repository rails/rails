module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module SchemaStatements # :nodoc:
        private
          def schema_creation
            MySQL::SchemaCreation.new(self)
          end

          def create_table_definition(*args)
            MySQL::TableDefinition.new(*args)
          end

          def new_column_from_field(table_name, field)
            type_metadata = fetch_type_metadata(field[:Type], field[:Extra])
            if type_metadata.type == :datetime && field[:Default] == "CURRENT_TIMESTAMP"
              default, default_function = nil, field[:Default]
            else
              default, default_function = field[:Default], nil
            end

            MySQL::Column.new(
              field[:Field],
              default,
              type_metadata,
              field[:Null] == "YES",
              table_name,
              default_function,
              field[:Collation],
              comment: field[:Comment].presence
            )
          end

          def fetch_type_metadata(sql_type, extra = "")
            MySQL::TypeMetadata.new(super(sql_type), extra: extra)
          end

          def extract_foreign_key_action(specifier)
            super unless specifier == "RESTRICT"
          end

          def data_source_sql(name = nil, type: nil)
            scope = quoted_scope(name, type: type)

            sql = "SELECT table_name FROM information_schema.tables"
            sql << " WHERE table_schema = #{scope[:schema]}"
            sql << " AND table_name = #{scope[:name]}" if scope[:name]
            sql << " AND table_type = #{scope[:type]}" if scope[:type]
            sql
          end

          def quoted_scope(name = nil, type: nil)
            schema, name = extract_schema_qualified_name(name)
            scope = {}
            scope[:schema] = schema ? quote(schema) : "database()"
            scope[:name] = quote(name) if name
            scope[:type] = quote(type) if type
            scope
          end

          def extract_schema_qualified_name(string)
            schema, name = string.to_s.scan(/[^`.\s]+|`[^`]*`/)
            schema, name = nil, schema unless name
            [schema, name]
          end
      end
    end
  end
end
