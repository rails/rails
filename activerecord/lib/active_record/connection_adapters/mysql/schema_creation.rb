module ActiveRecord
  module ConnectionAdapters
    module MySQL
      class SchemaCreation < AbstractAdapter::SchemaCreation
        private

        def visit_DropForeignKey(name)
          "DROP FOREIGN KEY #{name}"
        end

        def visit_ColumnDefinition(o)
          o.sql_type = type_to_sql(o.type, o.limit, o.precision, o.scale, o.unsigned)
          super
        end

        def visit_AddColumnDefinition(o)
          add_column_position!(super, column_options(o.column))
        end

        def visit_ChangeColumnDefinition(o)
          change_column_sql = "CHANGE #{quote_column_name(o.name)} #{accept(o.column)}"
          add_column_position!(change_column_sql, column_options(o.column))
        end

        def column_options(o)
          column_options = super
          column_options[:charset] = o.charset
          column_options
        end

        def add_column_options!(sql, options)
          if options[:charset]
            sql << " CHARACTER SET #{options[:charset]}"
          end
          if options[:collation]
            sql << " COLLATE #{options[:collation]}"
          end
          super
        end

        def add_column_position!(sql, options)
          if options[:first]
            sql << " FIRST"
          elsif options[:after]
            sql << " AFTER #{quote_column_name(options[:after])}"
          end
          sql
        end

        def index_in_create(table_name, column_name, options)
          index_name, index_type, index_columns, _, _, index_using = @conn.add_index_options(table_name, column_name, options)
          "#{index_type} INDEX #{quote_column_name(index_name)} #{index_using} (#{index_columns}) "
        end
      end
    end
  end
end
