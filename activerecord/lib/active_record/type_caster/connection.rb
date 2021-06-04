# frozen_string_literal: true

module ActiveRecord
  module TypeCaster
    class Connection # :nodoc:
      def initialize(klass, table_name)
        @klass = klass
        @table_name = table_name
      end

      def type_cast_for_database(attr_name, value)
        type = type_for_attribute(attr_name)
        type.serialize(value)
      end

      def type_for_attribute(attr_name)
        schema_cache = connection.schema_cache

        if schema_cache.data_source_exists?(table_name)
          column = schema_cache.columns_hash(table_name)[attr_name.to_s]
          type = connection.lookup_cast_type_from_column(column) if column
        end

        type || Type.default_value
      end

      delegate :connection, to: :@klass, private: true

      private
        attr_reader :table_name
    end
  end
end
