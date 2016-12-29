module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module ColumnDumper
        private

          def default_primary_key?(column)
            schema_type(column) == :integer
          end
      end
    end
  end
end
