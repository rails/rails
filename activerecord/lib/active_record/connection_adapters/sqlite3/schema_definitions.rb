# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        def change_column(column_name, type, **options)
          name = column_name.to_s
          @columns_hash[name] = nil
          column(name, type, **options)
        end

        def references(*args, **options)
          super(*args, type: :integer, **options)
        end
        alias :belongs_to :references

        private
          def integer_like_primary_key_type(type, options)
            :primary_key
          end
      end
    end
  end
end
