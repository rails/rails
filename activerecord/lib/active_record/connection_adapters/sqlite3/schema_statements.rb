module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module SchemaStatements # :nodoc:
        private
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
