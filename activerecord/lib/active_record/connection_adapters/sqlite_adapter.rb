# sqlite_adapter.rb
# author: Luke Holden <lholden@cablelan.net>
# updated for SQLite3: Jamis Buck <jamis_buck@byu.edu>

require 'active_record/connection_adapters/abstract_adapter'

module ActiveRecord
  class Base
    class << self
      # sqlite3 adapter reuses sqlite_connection.
      def sqlite3_connection(config) # :nodoc:
        parse_config!(config)

        unless self.class.const_defined?(:SQLite3)
          require_library_or_gem(config[:adapter])
        end

        db = SQLite3::Database.new(
          config[:dbfile],
          :results_as_hash => true,
          :type_translation => false
        )
        ConnectionAdapters::SQLiteAdapter.new(db, logger)
      end

      # Establishes a connection to the database that's used by all Active Record objects
      def sqlite_connection(config) # :nodoc:
        parse_config!(config)

        unless self.class.const_defined?(:SQLite)
          require_library_or_gem(config[:adapter])

          db = SQLite::Database.new(config[:dbfile], 0)
          db.show_datatypes   = "ON" if !defined? SQLite::Version
          db.results_as_hash  = true if defined? SQLite::Version
          db.type_translation = false

          # "Downgrade" deprecated sqlite API
          if SQLite.const_defined?(:Version)
            ConnectionAdapters::SQLiteAdapter.new(db, logger)
          else
            ConnectionAdapters::DeprecatedSQLiteAdapter.new(db, logger)
          end
        end
      end

      private
        def parse_config!(config)
          # Require dbfile.
          unless config.has_key?(:dbfile)
            raise ArgumentError, "No database file specified. Missing argument: dbfile"
          end

          # Allow database path relative to RAILS_ROOT.
          if Object.const_defined?(:RAILS_ROOT)
            config[:dbfile] = File.expand_path(config[:dbfile], RAILS_ROOT)
          end
        end
    end
  end

  module ConnectionAdapters #:nodoc:
    class SQLiteColumn < Column #:nodoc:
      def string_to_binary(value)
        value.gsub(/(\0|\%)/) do
          case $1
            when "\0" then "%00"
            when "%" then "%25"
          end
        end                
      end
      
      def binary_to_string(value)
        value.gsub(/(%00|%25)/) do
          case $1
            when "%00" then "\0"
            when "%25" then "%"
          end
        end                
      end
    end

    # The SQLite adapter works with both the 2.x and 3.x series of SQLite with the sqlite-ruby drivers (available both as gems and
    # from http://rubyforge.org/projects/sqlite-ruby/).
    #
    # Options:
    #
    # * <tt>:dbfile</tt> -- Path to the database file.
    class SQLiteAdapter < AbstractAdapter
      def native_database_types
        {
          :primary_key => "INTEGER PRIMARY KEY NOT NULL",
          :string      => { :name => "varchar", :limit => 255 },
          :text        => { :name => "text" },
          :integer     => { :name => "integer" },
          :float       => { :name => "float" },
          :datetime    => { :name => "datetime" },
          :timestamp   => { :name => "datetime" },
          :time        => { :name => "datetime" },
          :date        => { :name => "date" },
          :binary      => { :name => "blob" },
          :boolean     => { :name => "integer" }
        }
      end

      def execute(sql, name = nil)
        #log(sql, name, @connection) { |connection| connection.execute(sql) }
        log(sql, name) { @connection.execute(sql) }
      end

      def update(sql, name = nil)
        execute(sql, name)
        @connection.changes
      end

      def delete(sql, name = nil)
        sql += " WHERE 1=1" unless sql =~ /WHERE/i
        execute(sql, name)
        @connection.changes
      end

      def insert(sql, name = nil, pk = nil, id_value = nil)
        execute(sql, name = nil)
        id_value || @connection.last_insert_row_id
      end

      def select_all(sql, name = nil)
        execute(sql, name).map do |row|
          record = {}
          row.each_key do |key|
            if key.is_a?(String)
              record[key.sub(/^\w+\./, '')] = row[key]
            end
          end
          record
        end
      end

      def select_one(sql, name = nil)
        result = select_all(sql, name)
        result.nil? ? nil : result.first
      end


      def begin_db_transaction()    @connection.transaction end
      def commit_db_transaction()   @connection.commit      end
      def rollback_db_transaction() @connection.rollback    end


      def tables
        execute('.table').map { |table| Table.new(table) }
      end

      def columns(table_name, name = nil)
        table_structure(table_name).map { |field|
          SQLiteColumn.new(field['name'], field['dflt_value'], field['type'])
        }
      end

      def quote_string(s)
        @connection.class.quote(s)
      end

      def quote_column_name(name)
        "'#{name}'"
      end

      def adapter_name()
        'SQLite'
      end


      protected
        def table_structure(table_name)
          execute "PRAGMA table_info(#{table_name})"
        end
    end

    class DeprecatedSQLiteAdapter < SQLiteAdapter # :nodoc:
      def insert(sql, name = nil, pk = nil, id_value = nil)
        execute(sql, name = nil)
        id_value || @connection.last_insert_rowid
      end
    end
  end
end
