module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class SchemaCreation < AbstractAdapter::SchemaCreation # :nodoc:
        private
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
