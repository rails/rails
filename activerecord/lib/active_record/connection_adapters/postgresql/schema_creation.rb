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
