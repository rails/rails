# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      class SchemaDumper < ConnectionAdapters::SchemaDumper # :nodoc:
        private
          def default_primary_key?(column)
            schema_type(column) == :integer
          end

          def explicit_primary_key_default?(column)
            column.bigint?
          end

          def prepare_column_options(column)
            spec = super

            if @connection.supports_virtual_columns? && column.virtual?
              spec[:as] = extract_expression_for_virtual_column(column)
              spec[:stored] = column.virtual_stored?
              spec = { type: schema_type(column).inspect }.merge!(spec)
            end

            spec
          end

          def extract_expression_for_virtual_column(column)
            column.default_function.inspect
          end
      end
    end
  end
end
