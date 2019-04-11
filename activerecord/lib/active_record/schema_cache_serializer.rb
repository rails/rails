# frozen_string_literal: true

module ActiveRecord
  class SchemaCacheSerializer # :nodoc:
    cattr_accessor :tables_to_ignore, default: ["ar_internal_metadata"], instance_writer: false

    def initialize(connection)
      @connection = connection
    end

    def serialize
      serialized_schema = { columns: {}, data_sources: {}, primary_keys: {}, indexes: {} }
      @connection.schema_cache.clear!

      @connection.data_sources.each do |table|
        next if tables_to_ignore.include?(table)

        serialized_schema[:columns][table] = @connection.column_definitions(table).to_a
        serialized_schema[:indexes][table] = @connection.index_definitions(table).to_a
        serialized_schema[:data_sources][table] = true
        serialized_schema[:primary_keys][table] = @connection.primary_key(table)
      end
      serialized_schema[:version] = @connection.migration_context.current_version

      serialized_schema
    end

    def deserialize(schema_cache_file)
      return unless File.exist?(schema_cache_file)

      cache = YAML.load_file(schema_cache_file)

      if cache.is_a?(ActiveRecord::ConnectionAdapters::SchemaCache)
        cache
      elsif cache.is_a?(Hash)
        columns, columns_hash = deserialize_columns(cache[:columns])

        {
          version: cache[:version],
          primary_keys: cache[:primary_keys],
          data_sources: cache[:data_sources],
          indexes: deserialize_indexes(cache[:indexes]),
          columns: columns,
          columns_hash: columns_hash
        }
      end
    end

    private
      def deserialize_columns(serialized_schema)
        columns = {}
        columns_hash = {}

        serialized_schema.each do |table, serialized_columns|
          columns[table] = serialized_columns.map do |sc|
            @connection.new_column_from_field(table, sc)
          end

          columns_hash[table] = Hash[columns[table].map { |col| [col.name, col] } ]
        end

        [columns, columns_hash]
      end

      def deserialize_indexes(serialized_schema)
        indexes = {}

        serialized_schema.each do |table, serialized_indexes|
          indexes[table] = @connection.new_indexes_from_fields(serialized_indexes, table)
        end

        indexes
      end
  end
end
