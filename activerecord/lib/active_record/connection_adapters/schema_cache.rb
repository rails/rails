module ActiveRecord
  module ConnectionAdapters
    class SchemaCache
      attr_reader :columns, :columns_hash, :primary_keys, :tables
      attr_reader :column_defaults
      attr_reader :connection

      def initialize(conn)
        @connection = conn
        @tables              = {}

        @columns     = Hash.new do |h, table_name|
          h[table_name] =
            # Fetch a list of columns
            conn.columns(table_name, "#{table_name} Columns").tap do |cs|
              # set primary key information
              cs.each do |column|
                column.primary = column.name == primary_keys[table_name]
              end
            end
        end

        @columns_hash = Hash.new do |h, table_name|
          h[table_name] = Hash[columns[table_name].map { |col|
            [col.name, col]
          }]
        end

        @column_defaults = Hash.new do |h, table_name|
          h[table_name] = Hash[columns[table_name].map { |col|
            [col.name, col.default]
          }]
        end

        @primary_keys = Hash.new do |h, table_name|
          h[table_name] = table_exists?(table_name) ?
                          conn.primary_key(table_name) : 'id'
        end
      end

      # A cached lookup for table existence.
      def table_exists?(name)
        return @tables[name] if @tables.key? name

        connection.tables.each { |table| @tables[table] = true }
        @tables[name] = connection.table_exists?(name) if !@tables.key?(name)

        @tables[name]
      end

      # Clears out internal caches:
      #
      #   * columns
      #   * columns_hash
      #   * tables
      def clear!
        @columns.clear
        @columns_hash.clear
        @column_defaults.clear
        @tables.clear
      end

      # Clear out internal caches for table with +table_name+.
      def clear_table_cache!(table_name)
        @columns.delete table_name
        @columns_hash.delete table_name
        @column_defaults.delete table_name
        @primary_keys.delete table_name
      end
    end
  end
end
