# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      class SchemaCreation < SchemaCreation # :nodoc:
        delegate :add_sql_comment!, :mariadb?, to: :@conn, private: true

        private
          def visit_DropForeignKey(name)
            "DROP FOREIGN KEY #{name}"
          end

          def visit_DropCheckConstraint(name)
            "DROP #{mariadb? ? 'CONSTRAINT' : 'CHECK'} #{name}"
          end

          def visit_AddColumnDefinition(o)
            add_column_position!(super, column_options(o.column))
          end

          def visit_ChangeColumnDefinition(o)
            change_column_sql = +"CHANGE #{quote_column_name(o.name)} #{accept(o.column)}"
            add_column_position!(change_column_sql, column_options(o.column))
          end

          def visit_CreateIndexDefinition(o)
            sql = visit_IndexDefinition(o.index, true)
            sql << " #{o.algorithm}" if o.algorithm
            sql
          end

          def visit_IndexDefinition(o, create = false)
            index_type = o.type&.to_s&.upcase || o.unique && "UNIQUE"

            sql = create ? ["CREATE"] : []
            sql << index_type if index_type
            sql << "INDEX"
            sql << quote_column_name(o.name)
            sql << "USING #{o.using}" if o.using
            sql << "ON #{quote_table_name(o.table)}" if create
            sql << "(#{quoted_columns(o)})"

            add_sql_comment!(sql.join(" "), o.comment)
          end

          def add_table_options!(create_sql, o)
            create_sql = super
            create_sql << " DEFAULT CHARSET=#{o.charset}" if o.charset
            create_sql << " COLLATE=#{o.collation}" if o.collation
            add_sql_comment!(create_sql, o.comment)
          end

          def add_column_options!(sql, options)
            # By default, TIMESTAMP columns are NOT NULL, cannot contain NULL values,
            # and assigning NULL assigns the current timestamp. To permit a TIMESTAMP
            # column to contain NULL, explicitly declare it with the NULL attribute.
            # See https://dev.mysql.com/doc/refman/en/timestamp-initialization.html
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
            index, _ = @conn.add_index_options(table_name, column_name, **options)
            accept(index)
          end
      end
    end
  end
end
