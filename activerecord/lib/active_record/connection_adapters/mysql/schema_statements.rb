module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module SchemaStatements # :nodoc:
        def internal_string_options_for_primary_key
          super.tap do |options|
            if CHARSETS_OF_4BYTES_MAXLEN.include?(charset) && (mariadb? || version < "8.0.0")
              options[:collation] = collation.sub(/\A[^_]+/, "utf8")
            end
          end
        end

        private
          CHARSETS_OF_4BYTES_MAXLEN = ["utf8mb4", "utf16", "utf16le", "utf32"]

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
