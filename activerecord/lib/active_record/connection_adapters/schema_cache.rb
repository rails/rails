# frozen_string_literal: true

require "active_support/core_ext/file/atomic"

module ActiveRecord
  module ConnectionAdapters
    class SchemaCache
      class SchemaCacheData
        attr_accessor :columns, :columns_hash, :primary_keys, :data_sources, :indexes, :version, :database_version

        def initialize
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
      end

      def self.load_from(filename)
        return unless File.file?(filename)

        read(filename) do |file|
          filename.include?(".dump") ? Marshal.load(file) : YAML.load(file)
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

      attr_accessor :connection
      attr_writer :data

      def initialize(conn, data: nil)
        @connection = conn
        @data = data
      end

      def data
        @data ||= SchemaCacheData.new
      end

      def initialize_dup(other)
        super
        @data = @data.dup
      end

      def encode_with(coder)
        reset_version!

        coder["columns"]          = data.columns
        coder["primary_keys"]     = data.primary_keys
        coder["data_sources"]     = data.data_sources
        coder["indexes"]          = data.indexes
        coder["version"]          = data.version
        coder["database_version"] = database_version
      end

      def init_with(coder)
        data.columns          = coder["columns"]
        data.primary_keys     = coder["primary_keys"]
        data.data_sources     = coder["data_sources"]
        data.indexes          = coder["indexes"] || {}
        data.version          = coder["version"]
        data.database_version = coder["database_version"]

        derive_columns_hash_and_deduplicate_values
      end

      def version
        data.version
      end

      def primary_keys(table_name)
        data.primary_keys.fetch(table_name) do
          if data_source_exists?(table_name)
            data.primary_keys[deep_deduplicate(table_name)] = deep_deduplicate(connection.primary_key(table_name))
          end
        end
      end

      # A cached lookup for table existence.
      def data_source_exists?(name)
        prepare_data_sources if data.data_sources.empty?
        return data.data_sources[name] if data.data_sources.key? name

        data.data_sources[deep_deduplicate(name)] = connection.data_source_exists?(name)
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
        data.data_sources[name]
      end

      # Get the columns for a table
      def columns(table_name)
        data.columns.fetch(table_name) do
          data.columns[deep_deduplicate(table_name)] = deep_deduplicate(connection.columns(table_name))
        end
      end

      # Get the columns for a table as a hash, key is the column name
      # value is the column object.
      def columns_hash(table_name)
        data.columns_hash.fetch(table_name) do
          data.columns_hash[deep_deduplicate(table_name)] = columns(table_name).index_by(&:name)
        end
      end

      # Checks whether the columns hash is already cached for a table.
      def columns_hash?(table_name)
        data.columns_hash.key?(table_name)
      end

      def indexes(table_name)
        data.indexes.fetch(table_name) do
          data.indexes[deep_deduplicate(table_name)] = deep_deduplicate(connection.indexes(table_name))
        end
      end

      def database_version # :nodoc:
        data.database_version ||= connection.get_database_version
      end

      # Clears out internal caches
      def clear!
        data.columns.clear
        data.columns_hash.clear
        data.primary_keys.clear
        data.data_sources.clear
        data.indexes.clear
        data.version = nil
        data.database_version = nil
      end

      def size
        [data.columns, data.columns_hash, data.primary_keys, data.data_sources].sum(&:size)
      end

      # Clear out internal caches for the data source +name+.
      def clear_data_source_cache!(name)
        data.columns.delete name
        data.columns_hash.delete name
        data.primary_keys.delete name
        data.data_sources.delete name
        data.indexes.delete name
      end

      def dump_to(filename)
        clear!
        connection.data_sources.each { |table| add(table) }
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

        [data.version, data.columns, {}, data.primary_keys, data.data_sources, data.indexes, database_version]
      end

      def marshal_load(array)
        data.version, data.columns, _columns_hash, data.primary_keys, data.data_sources, data.indexes, data.database_version = array
        data.indexes ||= {}

        derive_columns_hash_and_deduplicate_values
      end

      private
        def reset_version!
          data.version = connection.migration_context.current_version
        end

        def derive_columns_hash_and_deduplicate_values
          data.columns      = deep_deduplicate(data.columns)
          data.columns_hash = data.columns.transform_values { |columns| columns.index_by(&:name) }
          data.primary_keys = deep_deduplicate(data.primary_keys)
          data.data_sources = deep_deduplicate(data.data_sources)
          data.indexes      = deep_deduplicate(data.indexes)
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
          connection.data_sources.each { |source| data.data_sources[source] = true }
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
