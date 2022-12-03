# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        attr_reader :strict_table

        def initialize(conn, name, strict_table: false, **options)
          @strict_table = strict_table
          super(conn, name, **options)
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
