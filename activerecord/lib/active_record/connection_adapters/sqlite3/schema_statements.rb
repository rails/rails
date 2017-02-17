module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module SchemaStatements # :nodoc:
        private
          def schema_creation
            SQLite3::SchemaCreation.new(self)
          end

          def create_table_definition(*args)
            SQLite3::TableDefinition.new(*args)
          end

          def new_column_from_field(table_name, field)
            default = \
              case field["dflt_value"]
              when /^null$/i
                nil
              when /^'(.*)'$/m
                $1.gsub("''", "'")
              when /^"(.*)"$/m
                $1.gsub('""', '"')
              else
                field["dflt_value"]
              end

            type_metadata = fetch_type_metadata(field["type"])
            Column.new(field["name"], default, type_metadata, field["notnull"].to_i == 0, table_name, nil, field["collation"])
          end

          def data_source_sql(name = nil, type: nil)
            scope = quoted_scope(name, type: type)
            scope[:type] ||= "'table','view'"

            sql = "SELECT name FROM sqlite_master WHERE name <> 'sqlite_sequence'"
            sql << " AND name = #{scope[:name]}" if scope[:name]
            sql << " AND type IN (#{scope[:type]})"
            sql
          end

          def quoted_scope(name = nil, type: nil)
            type = \
              case type
              when "BASE TABLE"
                "'table'"
              when "VIEW"
                "'view'"
              end
            scope = {}
            scope[:name] = quote(name) if name
            scope[:type] = type if type
            scope
          end
      end
    end
  end
end
