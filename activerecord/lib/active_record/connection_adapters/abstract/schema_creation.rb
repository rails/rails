module ActiveRecord
  module ConnectionAdapters
    class AbstractAdapter
      class SchemaCreation # :nodoc:
        def initialize(conn)
          @conn = conn
          @cache = {}
        end

        def accept(o)
          m = @cache[o.class] ||= "visit_#{o.class.name.split('::').last}"
          send m, o
        end

        def visit_AddColumn(o)
          sql_type = type_to_sql(o.type.to_sym, o.limit, o.precision, o.scale)
          sql = "ADD #{quote_column_name(o.name)} #{sql_type}"
          add_column_options!(sql, column_options(o))
        end

        private

          def visit_AlterTable(o)
            sql = "ALTER TABLE #{quote_table_name(o.name)} "
            sql << o.adds.map { |col| visit_AddColumn col }.join(' ')
          end

          def visit_ColumnDefinition(o)
            sql_type = type_to_sql(o.type.to_sym, o.limit, o.precision, o.scale)
            column_sql = "#{quote_column_name(o.name)} #{sql_type}"
            add_column_options!(column_sql, column_options(o)) unless o.primary_key?
            column_sql
          end

          def visit_TableDefinition(o)
            create_sql = "CREATE#{' TEMPORARY' if o.temporary} TABLE "
            create_sql << "#{quote_table_name(o.name)} "
            create_sql << "(#{o.columns.map { |c| accept c }.join(', ')}) " unless o.as
            create_sql << "#{o.options}"
            create_sql << " AS #{@conn.to_sql(o.as)}" if o.as
            create_sql
          end

          def column_options(o)
            column_options = {}
            column_options[:null] = o.null unless o.null.nil?
            column_options[:default] = o.default unless o.default.nil?
            column_options[:column] = o
            column_options[:first] = o.first
            column_options[:after] = o.after
            column_options
          end

          def quote_column_name(name)
            @conn.quote_column_name name
          end

          def quote_table_name(name)
            @conn.quote_table_name name
          end

          def type_to_sql(type, limit, precision, scale)
            @conn.type_to_sql type.to_sym, limit, precision, scale
          end

          def add_column_options!(sql, options)
            sql << " DEFAULT #{quote_value(options[:default], options[:column])}" if options_include_default?(options)
            # must explicitly check for :null to allow change_column to work on migrations
            if options[:null] == false
              sql << " NOT NULL"
            end
            if options[:auto_increment] == true
              sql << " AUTO_INCREMENT"
            end
            sql
          end

          def quote_value(value, column)
            column.sql_type ||= type_to_sql(column.type, column.limit, column.precision, column.scale)

            @conn.quote(value, column)
          end

          def options_include_default?(options)
            options.include?(:default) && !(options[:null] == false && options[:default].nil?)
          end
      end
    end
  end
end
