# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      class SchemaCreation < AbstractAdapter::SchemaCreation # :nodoc:
        private
          def visit_AddColumnDefinition(o)
            sql = "ADD #{accept(o.column)}"
            sql += " REFERENCES #{o.column.references}" if o.column.references
            sql.dup
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
