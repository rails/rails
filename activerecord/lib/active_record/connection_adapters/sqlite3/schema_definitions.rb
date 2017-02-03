module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module ColumnMethods
        def primary_key(name, type = :primary_key, **options)
          if %i(integer bigint).include?(type) && (options.delete(:auto_increment) == true || !options.key?(:default))
            type = :primary_key
          end

          super
        end
      end

      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        include ColumnMethods
      end

      class Table < ActiveRecord::ConnectionAdapters::Table
        include ColumnMethods
      end
    end
  end
end
