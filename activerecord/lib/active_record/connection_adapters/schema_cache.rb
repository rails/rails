module ActiveRecord
  module ConnectionAdapters
    class SchemaCache
      attr_reader :primary_keys, :tables
      attr_reader :connection

      def initialize(conn)
        @connection = conn
        @tables     = {}

        @columns = Hash.new do |h, table_name|
          h[table_name] = conn.columns(table_name, "#{table_name} Columns")
        end

        @columns_hash = Hash.new do |h, table_name|
          h[table_name] = Hash[columns[table_name].map { |col|
            [col.name, col]
          }]
        end

        @primary_keys = Hash.new do |h, table_name|
          h[table_name] = table_exists?(table_name) ? conn.primary_key(table_name) : nil
        end
      end

      # A cached lookup for table existence.
      def table_exists?(name)
        return @tables[name] if @tables.key? name

        @tables[name] = connection.table_exists?(name)
      end

      # Get the columns for a table
      def columns(table = nil)
        if table
          @columns[table]
        else
          @columns
        end
      end

      # Get the columns for a table as a hash, key is the column name
      # value is the column object.
      def columns_hash(table = nil)
        if table
          @columns_hash[table]
        else
          @columns_hash
        end
      end

      # Clears out internal caches
      def clear!
        @columns.clear
        @columns_hash.clear
        @primary_keys.clear
        @tables.clear
      end

      # Clear out internal caches for table with +table_name+.
      def clear_table_cache!(table_name)
        @columns.delete table_name
        @columns_hash.delete table_name
        @primary_keys.delete table_name
        @tables.delete table_name
      end
    end
  end
end
