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
      end
    end
  end
end
