# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class SchemaCreation < AbstractAdapter::SchemaCreation # :nodoc:
        private
          def visit_AlterTable(o)
            super << o.constraint_validations.map { |fk| visit_ValidateConstraint fk }.join(" ")
          end

          def visit_AddForeignKey(o)
            super.dup.tap { |sql| sql << " NOT VALID" unless o.validate? }
          end

          def visit_ValidateConstraint(name)
            "VALIDATE CONSTRAINT #{quote_column_name(name)}"
          end

          def visit_ChangeColumnDefinition(o)
            column = o.column
            column.sql_type = type_to_sql(column.type, **column.options)
            quoted_column_name = quote_column_name(o.name)

            change_column_sql = +"ALTER COLUMN #{quoted_column_name} TYPE #{column.sql_type}"

            options = column_options(column)

            if options[:collation]
              change_column_sql << " COLLATE \"#{options[:collation]}\""
            end

            if options[:using]
              change_column_sql << " USING #{options[:using]}"
            elsif options[:cast_as]
              cast_as_type = type_to_sql(options[:cast_as], **options)
              change_column_sql << " USING CAST(#{quoted_column_name} AS #{cast_as_type})"
            end

            if options.key?(:default)
              if options[:default].nil?
                change_column_sql << ", ALTER COLUMN #{quoted_column_name} DROP DEFAULT"
              else
                quoted_default = quote_default_expression(options[:default], column)
                change_column_sql << ", ALTER COLUMN #{quoted_column_name} SET DEFAULT #{quoted_default}"
              end
            end

            if options.key?(:null)
              change_column_sql << ", ALTER COLUMN #{quoted_column_name} #{options[:null] ? 'DROP' : 'SET'} NOT NULL"
            end

            change_column_sql
          end

          def add_column_options!(sql, options)
            if options[:collation]
              sql << " COLLATE \"#{options[:collation]}\""
            end
            super
          end

          # Returns any SQL string to go between CREATE and TABLE. May be nil.
          def table_modifier_in_create(o)
            # A table cannot be both TEMPORARY and UNLOGGED, since all TEMPORARY
            # tables are already UNLOGGED.
            if o.temporary
              " TEMPORARY"
            elsif o.unlogged
              " UNLOGGED"
            end
          end
      end
    end
  end
end
