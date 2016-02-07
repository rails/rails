module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class SchemaCreation < AbstractAdapter::SchemaCreation
        private

        def visit_ColumnDefinition(o)
          o.sql_type = type_to_sql(o.type, o.limit, o.precision, o.scale, o.array)
          super
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
