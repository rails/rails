module ActiveRecord
  module ConnectionAdapters
    module MySQL
      class SchemaCreation < AbstractAdapter::SchemaCreation # :nodoc:
        delegate :add_sql_comment!, :mariadb?, to: :@conn
        private :add_sql_comment!, :mariadb?

        private

          def visit_DropForeignKey(name)
            "DROP FOREIGN KEY #{name}"
          end

          def visit_AddColumnDefinition(o)
            add_column_position!(super, column_options(o.column))
          end

          def visit_ChangeColumnDefinition(o)
            change_column_sql = "CHANGE #{quote_column_name(o.name)} #{accept(o.column)}"
            add_column_position!(change_column_sql, column_options(o.column))
          end

          def add_table_options!(create_sql, options)
            add_sql_comment!(super, options[:comment])
          end

          def add_column_options!(sql, options)
            # By default, TIMESTAMP columns are NOT NULL, cannot contain NULL values,
            # and assigning NULL assigns the current timestamp. To permit a TIMESTAMP
            # column to contain NULL, explicitly declare it with the NULL attribute.
            # See http://dev.mysql.com/doc/refman/5.7/en/timestamp-initialization.html
            if /\Atimestamp\b/.match?(options[:column].sql_type) && !options[:primary_key]
              sql << " NULL" unless options[:null] == false || options_include_default?(options)
            end

            if charset = options[:charset]
              sql << " CHARACTER SET #{charset}"
            end

            if collation = options[:collation]
              sql << " COLLATE #{collation}"
            end

            if as = options[:as]
              sql << " AS (#{as})"
              if options[:stored]
                sql << (mariadb? ? " PERSISTENT" : " STORED")
              end
            end

            add_sql_comment!(super, options[:comment])
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
            index_name, index_type, index_columns, _, _, index_using, comment = @conn.add_index_options(table_name, column_name, options)
            add_sql_comment!("#{index_type} INDEX #{quote_column_name(index_name)} #{index_using} (#{index_columns})", comment)
          end
      end
    end
  end
end
