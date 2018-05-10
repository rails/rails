# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        def references(*args, **options)
          super(*args, type: :integer, **options)
        end
        alias :belongs_to :references

        private
          def integer_like_primary_key_type(_type, _options)
            :primary_key
          end
      end
    end
  end
end
