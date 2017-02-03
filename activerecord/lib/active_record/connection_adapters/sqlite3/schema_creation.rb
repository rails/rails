module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      class SchemaCreation < AbstractAdapter::SchemaCreation
        private

          def column_options(o)
            options = super
            options[:null] = false if o.primary_key
            options
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
