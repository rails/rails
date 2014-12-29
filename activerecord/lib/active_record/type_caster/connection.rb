module ActiveRecord
  module TypeCaster
    class Connection
      def initialize(connection, table_name)
        @connection = connection
        @table_name = table_name
      end

      def type_cast_for_database(attribute_name, value)
        return value if value.is_a?(Arel::Nodes::BindParam)
        type = type_for(attribute_name)
        type.type_cast_for_database(value)
      end

      protected

      attr_reader :connection, :table_name

      private

      def type_for(attribute_name)
        if connection.schema_cache.table_exists?(table_name)
          column_for(attribute_name).cast_type
        else
          Type::Value.new
        end
      end

      def column_for(attribute_name)
        connection.schema_cache.columns_hash(table_name)[attribute_name.to_s]
      end
    end
  end
end
