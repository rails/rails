# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        def references(*args, **options)
          super(*args, type: :integer, **options)
        end
        alias :belongs_to :references

        def new_column_definition(name, type, **options) # :nodoc:
          if integer_like_primary_key?(type, options)
            type = :primary_key
          end

          super
        end
      end
    end
  end
end
