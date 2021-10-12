# frozen_string_literal: true

require "active_support/core_ext/file/atomic"

module ActiveRecord
  module ConnectionAdapters
    class SchemaCache
      def self.load_from(filename)
        return unless File.file?(filename)

        read(filename) do |file|
          if filename.include?(".dump")
            Marshal.load(file)
          else
            if YAML.respond_to?(:unsafe_load)
              YAML.unsafe_load(file)
            else
              YAML.load(file)
            end
          end
        end
      end

      def self.read(filename, &block)
        if File.extname(filename) == ".gz"
          Zlib::GzipReader.open(filename) { |gz|
            yield gz.read
          }
        else
          yield File.read(filename)
        end
      end
      private_class_method :read

      attr_reader :version
      attr_accessor :connection

      def initialize(conn)
        @connection = conn

        @columns      = {}
        @columns_hash = {}
        @primary_keys = {}
        @data_sources = {}
        @indexes      = {}
      end

      def initialize_dup(other)
        super
        @columns      = @columns.dup
        @columns_hash = @columns_hash.dup
        @primary_keys = @primary_keys.dup
        @data_sources = @data_sources.dup
        @indexes      = @indexes.dup
      end

      def encode_with(coder)
        reset_version!

        coder["columns"]          = @columns
        coder["primary_keys"]     = @primary_keys
        coder["data_sources"]     = @data_sources
        coder["indexes"]          = @indexes
        coder["version"]          = @version
        coder["database_version"] = database_version
      end

      def init_with(coder)
        @columns          = coder["columns"]
        @primary_keys     = coder["primary_keys"]
        @data_sources     = coder["data_sources"]
        @indexes          = coder["indexes"] || {}
        @version          = coder["version"]
        @database_version = coder["database_version"]

        derive_columns_hash_and_deduplicate_values
      end

      def primary_keys(table_name)
        @primary_keys.fetch(table_name) do
          if data_source_exists?(table_name)
            @primary_keys[deep_deduplicate(table_name)] = deep_deduplicate(connection.primary_key(table_name))
          end
        end
      end

      # A cached lookup for table existence.
      def data_source_exists?(name)
        return if ignored_table?(name)
        prepare_data_sources if @data_sources.empty?
        return @data_sources[name] if @data_sources.key? name

        @data_sources[deep_deduplicate(name)] = connection.data_source_exists?(name)
      end

      # Add internal cache for table with +table_name+.
      def add(table_name)
        if data_source_exists?(table_name)
          primary_keys(table_name)
          columns(table_name)
          columns_hash(table_name)
          indexes(table_name)
        end
      end

      def data_sources(name)
        @data_sources[name]
      end

      # Get the columns for a table
      def columns(table_name)
        if ignored_table?(table_name)
          raise ActiveRecord::StatementInvalid, "Table '#{table_name}' doesn't exist"
        end

        @columns.fetch(table_name) do
          @columns[deep_deduplicate(table_name)] = deep_deduplicate(connection.columns(table_name))
        end
      end

      # Get the columns for a table as a hash, key is the column name
      # value is the column object.
      def columns_hash(table_name)
        @columns_hash.fetch(table_name) do
          @columns_hash[deep_deduplicate(table_name)] = columns(table_name).index_by(&:name).freeze
        end
      end

      # Checks whether the columns hash is already cached for a table.
      def columns_hash?(table_name)
        @columns_hash.key?(table_name)
      end

      def indexes(table_name)
        @indexes.fetch(table_name) do
          if data_source_exists?(table_name)
            @indexes[deep_deduplicate(table_name)] = deep_deduplicate(connection.indexes(table_name))
          else
            []
          end
        end
      end

      def database_version # :nodoc:
        @database_version ||= connection.get_database_version
      end

      # Clears out internal caches
      def clear!
        @columns.clear
        @columns_hash.clear
        @primary_keys.clear
        @data_sources.clear
        @indexes.clear
        @version = nil
        @database_version = nil
      end

      def size
        [@columns, @columns_hash, @primary_keys, @data_sources].sum(&:size)
      end

      # Clear out internal caches for the data source +name+.
      def clear_data_source_cache!(name)
        @columns.delete name
        @columns_hash.delete name
        @primary_keys.delete name
        @data_sources.delete name
        @indexes.delete name
      end

      def dump_to(filename)
        clear!
        tables_to_cache.each { |table| add(table) }
        open(filename) { |f|
          if filename.include?(".dump")
            f.write(Marshal.dump(self))
          else
            f.write(YAML.dump(self))
          end
        }
      end

      def marshal_dump
        reset_version!

        [@version, @columns, {}, @primary_keys, @data_sources, @indexes, database_version]
      end

      def marshal_load(array)
        @version, @columns, _columns_hash, @primary_keys, @data_sources, @indexes, @database_version = array
        @indexes ||= {}

        derive_columns_hash_and_deduplicate_values
      end

      private
        def tables_to_cache
          connection.data_sources.reject do |table|
            ignored_table?(table)
          end
        end

        def ignored_table?(table_name)
          ActiveRecord.schema_cache_ignored_tables.any? do |ignored|
            ignored === table_name
          end
        end

        def reset_version!
          @version = connection.migration_context.current_version
        end

        def derive_columns_hash_and_deduplicate_values
          @columns      = deep_deduplicate(@columns)
          @columns_hash = @columns.transform_values { |columns| columns.index_by(&:name) }
          @primary_keys = deep_deduplicate(@primary_keys)
          @data_sources = deep_deduplicate(@data_sources)
          @indexes      = deep_deduplicate(@indexes)
        end

        def deep_deduplicate(value)
          case value
          when Hash
            value.transform_keys { |k| deep_deduplicate(k) }.transform_values { |v| deep_deduplicate(v) }
          when Array
            value.map { |i| deep_deduplicate(i) }
          when String, Deduplicable
            -value
          else
            value
          end
        end

        def prepare_data_sources
          tables_to_cache.each do |source|
            @data_sources[source] = true
          end
        end

        def open(filename)
          File.atomic_write(filename) do |file|
            if File.extname(filename) == ".gz"
              zipper = Zlib::GzipWriter.new file
              yield zipper
              zipper.flush
              zipper.close
            else
              yield file
            end
          end
        end
    end
  end
end
