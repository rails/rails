# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class SchemaCache
      attr_reader :version
      attr_accessor :connection

      attr_reader :postgresql_additional_type_records, :postgresql_known_coder_type_records

      def initialize(conn)
        @connection = conn

        @columns      = {}
        @columns_hash = {}
        @primary_keys = {}
        @data_sources = {}
        @postgresql_additional_type_records = []
        @postgresql_known_coder_type_records = []
      end

      def initialize_dup(other)
        super
        @columns      = @columns.dup
        @columns_hash = @columns_hash.dup
        @primary_keys = @primary_keys.dup
        @data_sources = @data_sources.dup
      end

      def encode_with(coder)
        reset_postgresql_type_records!

        coder["columns"] = @columns
        coder["columns_hash"] = @columns_hash
        coder["primary_keys"] = @primary_keys
        coder["data_sources"] = @data_sources
        coder["postgresql_additional_type_records"] = @postgresql_additional_type_records
        coder["postgresql_known_coder_type_records"] = @postgresql_known_coder_type_records
        coder["version"] = connection.migration_context.current_version
      end

      def init_with(coder)
        @columns = coder["columns"]
        @columns_hash = coder["columns_hash"]
        @primary_keys = coder["primary_keys"]
        @data_sources = coder["data_sources"]
        @postgresql_additional_type_records = coder["postgresql_additional_type_records"]
        @postgresql_known_coder_type_records = coder["postgresql_known_coder_type_records"]
        @version = coder["version"]
      end

      def primary_keys(table_name)
        @primary_keys[table_name] ||= data_source_exists?(table_name) ? connection.primary_key(table_name) : nil
      end

      # A cached lookup for table existence.
      def data_source_exists?(name)
        prepare_data_sources if @data_sources.empty?
        return @data_sources[name] if @data_sources.key? name

        @data_sources[name] = connection.data_source_exists?(name)
      end

      # Add internal cache for table with +table_name+.
      def add(table_name)
        if data_source_exists?(table_name)
          primary_keys(table_name)
          columns(table_name)
          columns_hash(table_name)
        end
      end

      def data_sources(name)
        @data_sources[name]
      end

      # Get the columns for a table
      def columns(table_name)
        @columns[table_name] ||= connection.columns(table_name)
      end

      # Get the columns for a table as a hash, key is the column name
      # value is the column object.
      def columns_hash(table_name)
        @columns_hash[table_name] ||= Hash[columns(table_name).map { |col|
          [col.name, col]
        }]
      end

      # Clears out internal caches
      def clear!
        @columns.clear
        @columns_hash.clear
        @primary_keys.clear
        @data_sources.clear
        @postgresql_additional_type_records = []
        @postgresql_known_coder_type_records = []
        @version = nil
      end

      def size
        [@columns, @columns_hash, @primary_keys, @data_sources].map(&:size).inject :+
      end

      # Clear out internal caches for the data source +name+.
      def clear_data_source_cache!(name)
        @columns.delete name
        @columns_hash.delete name
        @primary_keys.delete name
        @data_sources.delete name
      end

      def marshal_dump
        reset_postgresql_type_records!

        # if we get current version during initialization, it happens stack over flow.
        @version = connection.migration_context.current_version
        [@version, @columns, @columns_hash, @primary_keys, @data_sources, @postgresql_additional_type_records, @postgresql_known_coder_type_records]
      end

      def marshal_load(array)
        @version, @columns, @columns_hash, @primary_keys, @data_sources, @postgresql_additional_type_records, @postgresql_known_coder_type_records = array
      end

      private
        def reset_postgresql_type_records!
          @postgresql_additional_type_records = connection&.additional_type_records_cache
          @postgresql_known_coder_type_records = connection&.known_coder_type_records_cache
        end

        def prepare_data_sources
          connection.data_sources.each { |source| @data_sources[source] = true }
        end
    end
  end
end
