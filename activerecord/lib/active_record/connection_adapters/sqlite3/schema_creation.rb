# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      class SchemaCreation < SchemaCreation # :nodoc:
        private
          def visit_ForeignKeyDefinition(o)
            super.dup.tap do |sql|
              sql << " DEFERRABLE INITIALLY #{o.deferrable.to_s.upcase}" if o.deferrable
            end
          end

          def supports_index_using?
            false
          end

          def add_column_options!(sql, options)
            if options[:collation]
              sql << " COLLATE \"#{options[:collation]}\""
            end

            if as = options[:as]
              sql << " GENERATED ALWAYS AS (#{as})"

              if options[:stored]
                sql << " STORED"
              else
                sql << " VIRTUAL"
              end
            end
            super
          end
      end
    end
  end
end
