module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      class SchemaCreation < AbstractAdapter::SchemaCreation
        private
          def visit_TableDefinition(o)
            table_name = quote_table_name(o.name)
            create_sql = if o.temporary
                "CREATE TEMPORARY TABLE #{table_name} "
              elsif o.virtual
                "CREATE VIRTUAL TABLE #{table_name} USING #{o.virtual} "
              else
                "CREATE TABLE #{table_name} "
              end
            create_sql << "(#{o.columns.map { |c| accept c }.join(', ')}) " unless o.as
            create_sql << "#{o.options}"
            create_sql << " AS #{@conn.to_sql(o.as)}" if o.as
            create_sql
          end

          def add_column_options!(sql, options)
            if options[:collation]
              sql << " COLLATE \"#{options[:collation]}\""
            end
            super
          end
      end
    end
  end
end
