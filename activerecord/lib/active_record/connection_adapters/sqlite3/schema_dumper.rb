module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module ColumnDumper # :nodoc:
        private

          def default_primary_key?(column)
            schema_type(column) == :integer
          end

          def explicit_primary_key_default?(column)
            column.bigint?
          end
      end
    end
  end
end
