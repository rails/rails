# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      class SchemaCreation < SchemaCreation # :nodoc:
        private
          def supports_index_using?
            false
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
