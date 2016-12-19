module ActiveRecord
  module TypeCaster
    class Connection # :nodoc:
      def initialize(klass, table_name)
        @klass = klass
        @table_name = table_name
      end

      def type_cast_for_database(attribute_name, value)
        return value if value.is_a?(Arel::Nodes::BindParam)
        column = column_for(attribute_name)
        connection.type_cast_from_column(column, value)
      end

      # TODO Change this to private once we've dropped Ruby 2.2 support.
      # Workaround for Ruby 2.2 "private attribute?" warning.
      protected

        attr_reader :table_name
        delegate :connection, to: :@klass

      private

        def column_for(attribute_name)
          if connection.schema_cache.data_source_exists?(table_name)
            connection.schema_cache.columns_hash(table_name)[attribute_name.to_s]
          end
        end
    end
  end
end
