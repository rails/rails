module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module SchemaStatements # :nodoc:
        private
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
