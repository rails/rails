require 'active_record/connection_adapters/sqlite_adapter'

gem 'sqlite3', '~> 1.3.5'
require 'sqlite3'

module ActiveRecord
  class Base
    # sqlite3 adapter reuses sqlite_connection.
    def self.sqlite3_connection(config) # :nodoc:
      # Require database.
      unless config[:database]
        raise ArgumentError, "No database file specified. Missing argument: database"
      end

      # Allow database path relative to Rails.root, but only if
      # the database path is not the special path that tells
      # Sqlite to build a database only in memory.
      if defined?(Rails.root) && ':memory:' != config[:database]
        config[:database] = File.expand_path(config[:database], Rails.root)
      end

      unless 'sqlite3' == config[:adapter]
        raise ArgumentError, 'adapter name should be "sqlite3"'
      end

      db = SQLite3::Database.new(
        config[:database],
        :results_as_hash => true
      )

      db.busy_timeout(config[:timeout]) if config[:timeout]

      ConnectionAdapters::SQLite3Adapter.new(db, logger, config)
    end
  end

  module ConnectionAdapters #:nodoc:
    class SQLite3Adapter < SQLiteAdapter # :nodoc:
      def quote(value, column = nil)
        if value.kind_of?(String) && column && column.type == :binary && column.class.respond_to?(:string_to_binary)
          s = column.class.string_to_binary(value).unpack("H*")[0]
          "x'#{s}'"
        else
          super
        end
      end

      # Returns the current database encoding format as a string, eg: 'UTF-8'
      def encoding
        @connection.encoding.to_s
      end

    end
  end
end
