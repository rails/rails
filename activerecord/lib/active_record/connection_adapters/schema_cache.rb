module ActiveRecord
  module ConnectionAdapters
    class SchemaCache
      attr_reader :version
      attr_accessor :connection

      def initialize(conn)
        @connection = conn

        @columns      = {}
        @columns_hash = {}
        @primary_keys = {}
        @data_sources = {}
      end

      def initialize_dup(other)
        super
        @columns      = @columns.dup
        @columns_hash = @columns_hash.dup
        @primary_keys = @primary_keys.dup
        @data_sources = @data_sources.dup
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
      alias table_exists? data_source_exists?
      deprecate :table_exists? => "use #data_source_exists? instead"


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
      alias tables data_sources
      deprecate :tables => "use #data_sources instead"

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
      alias clear_table_cache! clear_data_source_cache!
      deprecate :clear_table_cache! => "use #clear_data_source_cache! instead"

      def marshal_dump
        # if we get current version during initialization, it happens stack over flow.
        @version = ActiveRecord::Migrator.current_version
        [@version, @columns, @columns_hash, @primary_keys, @data_sources]
      end

      def marshal_load(array)
        @version, @columns, @columns_hash, @primary_keys, @data_sources = array
      end

      private

        def prepare_data_sources
          connection.data_sources.each { |source| @data_sources[source] = true }
        end
    end
  end
end
