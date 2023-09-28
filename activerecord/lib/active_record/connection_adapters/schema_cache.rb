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

      def set_schema_cache(cache)
        @cache = cache
      end

      def clear!
        @cache = empty_cache

        nil
      end

      def load!(connection)
        cache(connection)

        self
      end

      def primary_keys(connection, table_name)
        cache(connection).primary_keys(connection, table_name)
      end

      def data_source_exists?(connection, name)
        cache(connection).data_source_exists?(connection, name)
      end

      def add(connection, name)
        cache(connection).add(connection, name)
      end

      def data_sources(connection, name)
        cache(connection).data_sources(connection, name)
      end

      def columns(connection, table_name)
        cache(connection).columns(connection, table_name)
      end

      def columns_hash(connection, table_name)
        cache(connection).columns_hash(connection, table_name)
      end

      def columns_hash?(connection, table_name)
        cache(connection).columns_hash?(connection, table_name)
      end

      def indexes(connection, table_name)
        cache(connection).indexes(connection, table_name)
      end

      def database_version(connection) # :nodoc:
        cache(connection).database_version(connection)
      end

      def version(connection)
        cache(connection).version(connection)
      end

      def size(connection)
        cache(connection).size
      end

      def clear_data_source_cache!(connection, name)
        return if @cache.nil? && !possible_cache_available?

        cache(connection).clear_data_source_cache!(connection, name)
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

      def dump_to(connection, filename)
        fresh_cache = empty_cache
        fresh_cache.add_all(connection)
        fresh_cache.dump_to(filename)

        @cache = fresh_cache
      end

      private
        def empty_cache
          new_cache = SchemaCache.allocate
          new_cache.send(:initialize)
          new_cache
        end

        def cache(connection)
          @cache ||= load_cache(connection) || empty_cache
        end

        def possible_cache_available?
          self.class.use_schema_cache_dump &&
            @cache_path &&
            File.file?(@cache_path)
        end

        def load_cache(connection)
          # Can't load if schema dumps are disabled
          return unless possible_cache_available?

          # Check we can find one
          return unless new_cache = SchemaCache._load_from(@cache_path)

          if self.class.check_schema_cache_dump_version
            begin
              current_version = connection.schema_version

              if new_cache.version(connection) != current_version
                warn "Ignoring #{@cache_path} because it has expired. The current schema version is #{current_version}, but the one in the schema cache file is #{new_cache.schema_version}."
                return
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
      def initialize(abstract_schema_reflection, connection)
        @schema_reflection = abstract_schema_reflection
        @connection = connection
      end

      def clear!
        @schema_reflection.clear!
      end

      def load!
        @schema_reflection.load!(@connection)
      end

      def cached?(table_name)
        @schema_reflection.cached?(table_name)
      end

      def primary_keys(table_name)
        @schema_reflection.primary_keys(@connection, table_name)
      end

      def data_source_exists?(name)
        @schema_reflection.data_source_exists?(@connection, name)
      end

      def add(name)
        @schema_reflection.add(@connection, name)
      end

      def data_sources(name)
        @schema_reflection.data_sources(@connection, name)
      end

      def columns(table_name)
        @schema_reflection.columns(@connection, table_name)
      end

      def columns_hash(table_name)
        @schema_reflection.columns_hash(@connection, table_name)
      end

      def columns_hash?(table_name)
        @schema_reflection.columns_hash?(@connection, table_name)
      end

      def indexes(table_name)
        @schema_reflection.indexes(@connection, table_name)
      end

      def database_version # :nodoc:
        @schema_reflection.database_version(@connection)
      end

      def version
        @schema_reflection.version(@connection)
      end

      def size
        @schema_reflection.size(@connection)
      end

      def clear_data_source_cache!(name)
        @schema_reflection.clear_data_source_cache!(@connection, name)
      end

      def dump_to(filename)
        @schema_reflection.dump_to(@connection, filename)
      end
    end

    # = Active Record Connection Adapters Schema Cache
    class SchemaCache
      class << self
        def new(connection)
          BoundSchemaReflection.new(SchemaReflection.new(nil), connection)
        end
        deprecate new: "use ActiveRecord::ConnectionAdapters::SchemaReflection instead", deprecator: ActiveRecord.deprecator

        def load_from(filename) # :nodoc:
          BoundSchemaReflection.new(SchemaReflection.new(filename), nil)
        end
        deprecate load_from: "use ActiveRecord::ConnectionAdapters::SchemaReflection instead", deprecator: ActiveRecord.deprecator
      end

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

      def initialize
        @columns      = {}
        @columns_hash = {}
        @primary_keys = {}
        @data_sources = {}
        @indexes      = {}
        @database_version = nil
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
        coder["database_version"] = @database_version
      end

      def init_with(coder)
        @columns          = coder["columns"]
        @columns_hash     = coder["columns_hash"]
        @primary_keys     = coder["primary_keys"]
        @data_sources     = coder["data_sources"]
        @indexes          = coder["indexes"] || {}
        @version          = coder["version"]
        @database_version = coder["database_version"]

        unless coder["deduplicated"]
          derive_columns_hash_and_deduplicate_values
        end
      end

      def cached?(table_name)
        @columns.key?(table_name)
      end

      def primary_keys(connection, table_name)
        @primary_keys.fetch(table_name) do
          if data_source_exists?(connection, table_name)
            @primary_keys[deep_deduplicate(table_name)] = deep_deduplicate(connection.primary_key(table_name))
          end
        end
      end

      # A cached lookup for table existence.
      def data_source_exists?(connection, name)
        return if ignored_table?(name)
        prepare_data_sources(connection) if @data_sources.empty?
        return @data_sources[name] if @data_sources.key? name

        @data_sources[deep_deduplicate(name)] = connection.data_source_exists?(name)
      end

      # Add internal cache for table with +table_name+.
      def add(connection, table_name)
        if data_source_exists?(connection, table_name)
          primary_keys(connection, table_name)
          columns(connection, table_name)
          columns_hash(connection, table_name)
          indexes(connection, table_name)
        end
      end

      def data_sources(_connection, name) # :nodoc:
        @data_sources[name]
      end
      deprecate data_sources: :data_source_exists?, deprecator: ActiveRecord.deprecator

      # Get the columns for a table
      def columns(connection, table_name)
        if ignored_table?(table_name)
          raise ActiveRecord::StatementInvalid, "Table '#{table_name}' doesn't exist"
        end

        @columns.fetch(table_name) do
          @columns[deep_deduplicate(table_name)] = deep_deduplicate(connection.columns(table_name))
        end
      end

      # Get the columns for a table as a hash, key is the column name
      # value is the column object.
      def columns_hash(connection, table_name)
        @columns_hash.fetch(table_name) do
          @columns_hash[deep_deduplicate(table_name)] = columns(connection, table_name).index_by(&:name).freeze
        end
      end

      # Checks whether the columns hash is already cached for a table.
      def columns_hash?(connection, table_name)
        @columns_hash.key?(table_name)
      end

      def indexes(connection, table_name)
        @indexes.fetch(table_name) do
          if data_source_exists?(connection, table_name)
            @indexes[deep_deduplicate(table_name)] = deep_deduplicate(connection.indexes(table_name))
          else
            []
          end
        end
      end

      def database_version(connection) # :nodoc:
        @database_version ||= connection.get_database_version
      end

      def version(connection)
        @version ||= connection.schema_version
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

      def add_all(connection) # :nodoc:
        tables_to_cache(connection).each do |table|
          add(connection, table)
        end

        version(connection)
        database_version(connection)
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
        [@version, @columns, {}, @primary_keys, @data_sources, @indexes, @database_version]
      end

      def marshal_load(array) # :nodoc:
        @version, @columns, _columns_hash, @primary_keys, @data_sources, @indexes, @database_version = array
        @indexes ||= {}

        derive_columns_hash_and_deduplicate_values
      end

      private
        def tables_to_cache(connection)
          connection.data_sources.reject do |table|
            ignored_table?(table)
          end
        end

        def ignored_table?(table_name)
          ActiveRecord.schema_cache_ignored_tables.any? do |ignored|
            ignored === table_name
          end
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

        def prepare_data_sources(connection)
          tables_to_cache(connection).each do |source|
            @data_sources[source] = true
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
