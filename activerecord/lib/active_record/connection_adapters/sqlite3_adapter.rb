require 'active_record/connection_adapters/sqlite_adapter'

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

      unless self.class.const_defined?(:SQLite3)
        require_library_or_gem(config[:adapter])
      end

      db = SQLite3::Database.new(
        config[:database],
        :results_as_hash => true
      )

      db.busy_timeout(config[:timeout]) unless config[:timeout].nil?

      ConnectionAdapters::SQLite3Adapter.new(db, logger, config)
    end
  end

  module ConnectionAdapters #:nodoc:
    class SQLite3Adapter < SQLiteAdapter # :nodoc:

      # Returns the current database encoding format as a string, eg: 'UTF-8'
      def encoding
        if @connection.respond_to?(:encoding)
          @connection.encoding.to_s
        else
          encoding = @connection.execute('PRAGMA encoding')
          encoding[0]['encoding']
        end
      end

    end
  end
end
