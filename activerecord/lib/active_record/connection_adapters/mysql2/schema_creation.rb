module ActiveRecord
  module ConnectionAdapters
    module Mysql2 # :nodoc:
      class SchemaCreation < AbstractAdapter::SchemaCreation # :nodoc:
        def visit_AddColumn(o)
          add_column_position!(super, column_options(o))
        end

        private
          def visit_DropForeignKey(name)
            "DROP FOREIGN KEY #{name}"
          end

          def visit_TableDefinition(o)
            name = o.name
            create_sql = "CREATE#{' TEMPORARY' if o.temporary} TABLE #{quote_table_name(name)} "

            statements = o.columns.map { |c| accept c }
            statements.concat(o.indexes.map { |column_name, options| index_in_create(name, column_name, options) })

            create_sql << "(#{statements.join(', ')}) " if statements.present?
            create_sql << o.options
            create_sql << " AS #{@conn.to_sql(o.as)}" if o.as
            create_sql
          end

          def visit_ChangeColumnDefinition(o)
            column = o.column
            options = o.options
            sql_type = type_to_sql(o.type, options[:limit], options[:precision], options[:scale])
            change_column_sql = "CHANGE #{quote_column_name(column.name)} #{quote_column_name(options[:name])} #{sql_type}"
            add_column_options!(change_column_sql, options.merge(column: column))
            add_column_position!(change_column_sql, options)
          end

          def add_column_position!(sql, options)
            if options[:first]
              sql << ' FIRST'
            elsif options[:after]
              sql << " AFTER #{quote_column_name(options[:after])}"
            end
            sql
          end

          def index_in_create(table_name, column_name, options)
            index_name, index_type, index_columns, index_options, index_algorithm, index_using = @conn.add_index_options(table_name, column_name, options)
            "#{index_type} INDEX #{quote_column_name(index_name)} #{index_using} (#{index_columns})#{index_options} #{index_algorithm}"
          end
      end
    end
  end
end

