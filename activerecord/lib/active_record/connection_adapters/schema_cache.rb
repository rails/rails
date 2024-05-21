# frozen_string_literal: true

require "active_support/core_ext/file/atomic"

module ActiveRecord
  module ConnectionAdapters
    class SchemaReflection
      class << self
        attr_accessor :use_schema_cache_dump
        attr_accessor :check_schema_cache_dump_version
      end

      self.use_schema_cache_dump = true
      self.check_schema_cache_dump_version = true

      def initialize(cache_path, cache = nil)
        @cache = cache
        @cache_path = cache_path
      end

      def clear!
        @cache = empty_cache

        nil
      end

      def load!(pool)
        cache(pool)

        self
      end

      def primary_keys(pool, table_name)
        cache(pool).primary_keys(pool, table_name)
      end

      def data_source_exists?(pool, name)
        cache(pool).data_source_exists?(pool, name)
      end

      def add(pool, name)
        cache(pool).add(pool, name)
      end

      def data_sources(pool, name)
        cache(pool).data_source_exists?(pool, name)
      end

      def columns(pool, table_name)
        cache(pool).columns(pool, table_name)
      end

      def columns_hash(pool, table_name)
        cache(pool).columns_hash(pool, table_name)
      end

      def columns_hash?(pool, table_name)
        cache(pool).columns_hash?(pool, table_name)
      end

      def indexes(pool, table_name)
        cache(pool).indexes(pool, table_name)
      end

      def version(pool)
        cache(pool).version(pool)
      end

      def size(pool)
        cache(pool).size
      end

      def clear_data_source_cache!(pool, name)
        return if @cache.nil? && !possible_cache_available?

        cache(pool).clear_data_source_cache!(pool, name)
      end

      def cached?(table_name)
        if @cache.nil?
          # If `check_schema_cache_dump_version` is enabled we can't load
          # the schema cache dump without connecting to the database.
          unless self.class.check_schema_cache_dump_version
            @cache = load_cache(nil)
          end
        end

        @cache&.cached?(table_name)
      end

      def dump_to(pool, filename)
        fresh_cache = empty_cache
        fresh_cache.add_all(pool)
        fresh_cache.dump_to(filename)

        @cache = fresh_cache
      end

      private
        def empty_cache
          new_cache = SchemaCache.allocate
          new_cache.send(:initialize)
          new_cache
        end

        def cache(pool)
          @cache ||= load_cache(pool) || empty_cache
        end

        def possible_cache_available?
          self.class.use_schema_cache_dump &&
            @cache_path &&
            File.file?(@cache_path)
        end

        def load_cache(pool)
          # Can't load if schema dumps are disabled
          return unless possible_cache_available?

          # Check we can find one
          return unless new_cache = SchemaCache._load_from(@cache_path)

          if self.class.check_schema_cache_dump_version
            begin
              pool.with_connection do |connection|
                current_version = connection.schema_version

                if new_cache.version(connection) != current_version
                  warn "Ignoring #{@cache_path} because it has expired. The current schema version is #{current_version}, but the one in the schema cache file is #{new_cache.schema_version}."
                  return
                end
              end
            rescue ActiveRecordError => error
              warn "Failed to validate the schema cache because of #{error.class}: #{error.message}"
              return
            end
          end

          new_cache
        end
    end

    class BoundSchemaReflection
      class FakePool # :nodoc
        def initialize(connection)
          @connection = connection
        end

        def with_connection
          yield @connection
        end
      end

      class << self
        def for_lone_connection(abstract_schema_reflection, connection) # :nodoc:
          new(abstract_schema_reflection, FakePool.new(connection))
        end
      end

      def initialize(abstract_schema_reflection, pool)
        @schema_reflection = abstract_schema_reflection
        @pool = pool
      end

      def clear!
        @schema_reflection.clear!
      end

      def load!
        @schema_reflection.load!(@pool)
      end

      def cached?(table_name)
        @schema_reflection.cached?(table_name)
      end

      def primary_keys(table_name)
        @schema_reflection.primary_keys(@pool, table_name)
      end

      def data_source_exists?(name)
        @schema_reflection.data_source_exists?(@pool, name)
      end

      def add(name)
        @schema_reflection.add(@pool, name)
      end

      def data_sources(name)
        @schema_reflection.data_sources(@pool, name)
      end

      def columns(table_name)
        @schema_reflection.columns(@pool, table_name)
      end

      def columns_hash(table_name)
        @schema_reflection.columns_hash(@pool, table_name)
      end

      def columns_hash?(table_name)
        @schema_reflection.columns_hash?(@pool, table_name)
      end

      def indexes(table_name)
        @schema_reflection.indexes(@pool, table_name)
      end

      def version
        @schema_reflection.version(@pool)
      end

      def size
        @schema_reflection.size(@pool)
      end

      def clear_data_source_cache!(name)
        @schema_reflection.clear_data_source_cache!(@pool, name)
      end

      def dump_to(filename)
        @schema_reflection.dump_to(@pool, filename)
      end
    end

    # = Active Record Connection Adapters Schema Cache
    class SchemaCache
      def self._load_from(filename) # :nodoc:
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

      def initialize # :nodoc:
        @columns      = {}
        @columns_hash = {}
        @primary_keys = {}
        @data_sources = {}
        @indexes      = {}
        @version = nil
      end

      def initialize_dup(other) # :nodoc:
        super
        @columns      = @columns.dup
        @columns_hash = @columns_hash.dup
        @primary_keys = @primary_keys.dup
        @data_sources = @data_sources.dup
        @indexes      = @indexes.dup
      end

      def encode_with(coder) # :nodoc:
        coder["columns"]          = @columns.sort.to_h
        coder["primary_keys"]     = @primary_keys.sort.to_h
        coder["data_sources"]     = @data_sources.sort.to_h
        coder["indexes"]          = @indexes.sort.to_h
        coder["version"]          = @version
      end

      def init_with(coder) # :nodoc:
        @columns          = coder["columns"]
        @columns_hash     = coder["columns_hash"]
        @primary_keys     = coder["primary_keys"]
        @data_sources     = coder["data_sources"]
        @indexes          = coder["indexes"] || {}
        @version          = coder["version"]

        unless coder["deduplicated"]
          derive_columns_hash_and_deduplicate_values
        end
      end

      def cached?(table_name)
        @columns.key?(table_name)
      end

      def primary_keys(pool, table_name)
        @primary_keys.fetch(table_name) do
          pool.with_connection do |connection|
            if data_source_exists?(pool, table_name)
              @primary_keys[deep_deduplicate(table_name)] = deep_deduplicate(connection.primary_key(table_name))
            end
          end
        end
      end

      # A cached lookup for table existence.
      def data_source_exists?(pool, name)
        return if ignored_table?(name)

        if @data_sources.empty?
          tables_to_cache(pool).each do |source|
            @data_sources[source] = true
          end
        end

        return @data_sources[name] if @data_sources.key? name

        @data_sources[deep_deduplicate(name)] = pool.with_connection do |connection|
          connection.data_source_exists?(name)
        end
      end

      # Add internal cache for table with +table_name+.
      def add(pool, table_name)
        pool.with_connection do
          if data_source_exists?(pool, table_name)
            primary_keys(pool, table_name)
            columns(pool, table_name)
            columns_hash(pool, table_name)
            indexes(pool, table_name)
          end
        end
      end

      # Get the columns for a table
      def columns(pool, table_name)
        if ignored_table?(table_name)
          raise ActiveRecord::StatementInvalid.new("Table '#{table_name}' doesn't exist", connection_pool: pool)
        end

        @columns.fetch(table_name) do
          pool.with_connection do |connection|
            @columns[deep_deduplicate(table_name)] = deep_deduplicate(connection.columns(table_name))
          end
        end
      end

      # Get the columns for a table as a hash, key is the column name
      # value is the column object.
      def columns_hash(pool, table_name)
        @columns_hash.fetch(table_name) do
          @columns_hash[deep_deduplicate(table_name)] = columns(pool, table_name).index_by(&:name).freeze
        end
      end

      # Checks whether the columns hash is already cached for a table.
      def columns_hash?(_pool, table_name)
        @columns_hash.key?(table_name)
      end

      def indexes(pool, table_name)
        @indexes.fetch(table_name) do
          pool.with_connection do |connection|
            if data_source_exists?(pool, table_name)
              @indexes[deep_deduplicate(table_name)] = deep_deduplicate(connection.indexes(table_name))
            else
              []
            end
          end
        end
      end

      def version(pool)
        @version ||= pool.with_connection(&:schema_version)
      end

      def schema_version
        @version
      end

      def size
        [@columns, @columns_hash, @primary_keys, @data_sources].sum(&:size)
      end

      # Clear out internal caches for the data source +name+.
      def clear_data_source_cache!(_connection, name)
        @columns.delete name
        @columns_hash.delete name
        @primary_keys.delete name
        @data_sources.delete name
        @indexes.delete name
      end

      def add_all(pool) # :nodoc:
        pool.with_connection do
          tables_to_cache(pool).each do |table|
            add(pool, table)
          end

          version(pool)
        end
      end

      def dump_to(filename)
        open(filename) { |f|
          if filename.include?(".dump")
            f.write(Marshal.dump(self))
          else
            f.write(YAML.dump(self))
          end
        }
      end

      def marshal_dump # :nodoc:
        [@version, @columns, {}, @primary_keys, @data_sources, @indexes]
      end

      def marshal_load(array) # :nodoc:
        @version, @columns, _columns_hash, @primary_keys, @data_sources, @indexes, _database_version = array
        @indexes ||= {}

        derive_columns_hash_and_deduplicate_values
      end

      private
        def tables_to_cache(pool)
          pool.with_connection do |connection|
            connection.data_sources.reject do |table|
              ignored_table?(table)
            end
          end
        end

        def ignored_table?(table_name)
          ActiveRecord.schema_cache_ignored_table?(table_name)
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

        def open(filename)
          FileUtils.mkdir_p(File.dirname(filename))

          File.atomic_write(filename) do |file|
            if File.extname(filename) == ".gz"
              zipper = Zlib::GzipWriter.new file
              zipper.mtime = 0
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
