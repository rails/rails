# sqlite_adapter.rb
# author:   Luke Holden <lholden@cablelan.net>

require 'active_record/connection_adapters/abstract_adapter'

begin
  require 'sqlite' unless self.class.const_defined?(:SQLite)

  module ActiveRecord
    class Base
      # Establishes a connection to the database that's used by all Active Record objects
      def self.sqlite_connection(config) # :nodoc:
        symbolize_strings_in_hash(config)
        unless config.has_key?(:dbfile)
          raise ArgumentError, "No database file specified. Missing argument: dbfile"
        end

        db = SQLite::Database.new(config[:dbfile], 0)
        db.show_datatypes   = "ON"
        db.type_translation = false
        
        self.connection = ConnectionAdapters::SQLiteAdapter.new(db, logger)
      end
    end

    module ConnectionAdapters
      class SQLiteAdapter < AbstractAdapter # :nodoc:
        def select_all(sql, name = nil)
          select(sql, name)
        end

        def select_one(sql, name = nil)
          result = select(sql, name)
          result.nil? ? nil : result.first
        end

        def columns(table_name, name = nil)
          table_structure(table_name).inject([]) do |columns, field| 
            columns << Column.new(field['name'], field['dflt_value'], field['type'])
            columns
          end
        end

        def insert(sql, name = nil)
          execute(sql, name = nil)
          @connection.last_insert_rowid()
        end

        def execute(sql, name = nil)
          log(sql, name, @connection) { |connection| connection.execute(sql) }
        end

        alias_method :update, :execute
        alias_method :delete, :execute

        def begin_db_transaction()    execute "BEGIN" end
        def commit_db_transaction()   execute "COMMIT" end
        def rollback_db_transaction() execute "ROLLBACK" end

        private
          def select(sql, name = nil)
            results = nil
            log(sql, name, @connection) { |connection| results = connection.execute(sql) }

            rows = []

            results.each do |row|
              hash_only_row = {}
              row.each_key do |key|
                hash_only_row[key.gsub(/\w\./, "")] = row[key] unless key.class == Fixnum
              end
              rows << hash_only_row
            end
            
            return rows
          end

          def table_structure(table_name)
            sql = "PRAGMA table_info(#{table_name});"
            results = nil
            log(sql, nil, @connection) { |connection| results = connection.execute(sql) }
            return results
          end
      end
    end
  end
rescue LoadError
  # SQLite driver is not availible
end