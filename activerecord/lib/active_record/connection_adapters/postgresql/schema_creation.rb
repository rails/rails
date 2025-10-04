# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class SchemaCreation < SchemaCreation # :nodoc:
        private
          delegate :quoted_include_columns_for_index, to: :@conn
          delegate :database_version, to: :@conn

          def visit_AlterTable(o)
            sql = super
            sql << o.constraint_validations.map { |fk| visit_ValidateConstraint fk }.join(" ")
            sql << o.exclusion_constraint_adds.map { |con| visit_AddExclusionConstraint con }.join(" ")
            sql << o.unique_constraint_adds.map { |con| visit_AddUniqueConstraint con }.join(" ")
          end

          def visit_AddForeignKey(o)
            super.dup.tap do |sql|
              sql << " NOT VALID" unless o.validate?
            end
          end

          def visit_ForeignKeyDefinition(o)
            super.dup.tap do |sql|
              sql << " DEFERRABLE INITIALLY #{o.deferrable.to_s.upcase}" if o.deferrable
            end
          end

          def visit_CheckConstraintDefinition(o)
            super.dup.tap { |sql| sql << " NOT VALID" unless o.validate? }
          end

          def visit_ValidateConstraint(name)
            "VALIDATE CONSTRAINT #{quote_column_name(name)}"
          end

          def visit_ExclusionConstraintDefinition(o)
            sql = ["CONSTRAINT"]
            sql << quote_column_name(o.name)
            sql << "EXCLUDE"
            sql << "USING #{o.using}" if o.using
            sql << "(#{o.expression})"
            sql << "WHERE (#{o.where})" if o.where
            sql << "DEFERRABLE INITIALLY #{o.deferrable.to_s.upcase}" if o.deferrable

            sql.join(" ")
          end

          def visit_UniqueConstraintDefinition(o)
            column_name = Array(o.column).map { |column| quote_column_name(column) }.join(", ")

            sql = ["CONSTRAINT"]
            sql << quote_column_name(o.name)
            sql << "UNIQUE"
            sql << "NULLS NOT DISTINCT" if supports_nulls_not_distinct? && o.nulls_not_distinct

            if o.using_index
              sql << "USING INDEX #{quote_column_name(o.using_index)}"
            else
              sql << "(#{column_name})"
            end

            if o.deferrable
              sql << "DEFERRABLE INITIALLY #{o.deferrable.to_s.upcase}"
            end

            sql.join(" ")
          end

          def visit_AddExclusionConstraint(o)
            "ADD #{accept(o)}"
          end

          def visit_AddUniqueConstraint(o)
            "ADD #{accept(o)}"
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
                quoted_default = quote_default_expression_for_column_definition(options[:default], column)
                change_column_sql << ", ALTER COLUMN #{quoted_column_name} SET DEFAULT #{quoted_default}"
              end
            end

            if options.key?(:null)
              change_column_sql << ", ALTER COLUMN #{quoted_column_name} #{options[:null] ? 'DROP' : 'SET'} NOT NULL"
            end

            change_column_sql
          end

          def visit_ChangeColumnDefaultDefinition(o)
            sql = +"ALTER COLUMN #{quote_column_name(o.column.name)} "
            if o.default.nil?
              sql << "DROP DEFAULT"
            else
              sql << "SET DEFAULT #{quote_default_expression(o.default, o.column)}"
            end
          end

          def add_column_options!(sql, options)
            if options[:collation]
              sql << " COLLATE \"#{options[:collation]}\""
            end

            if as = options[:as]
              stored = options[:stored]

              if stored != true && database_version < 18_00_00
                raise ArgumentError, <<~MSG
                  PostgreSQL versions before 18 do not support VIRTUAL (not persisted) generated columns.
                  Specify 'stored: true' option for '#{options[:column].name}'
                MSG
              end

              sql << " GENERATED ALWAYS AS (#{as})"
              sql << (stored ? " STORED" : " VIRTUAL")
            end
            super
          end

          def quoted_include_columns(o)
            String === o ? o : quoted_include_columns_for_index(o)
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
