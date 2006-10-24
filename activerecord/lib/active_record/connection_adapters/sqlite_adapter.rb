# Author: Luke Holden <lholden@cablelan.net>
# Updated for SQLite3: Jamis Buck <jamis@37signals.com>

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
          config[:database],
          :results_as_hash => true,
          :type_translation => false
        )

        db.busy_timeout(config[:timeout]) unless config[:timeout].nil?

        ConnectionAdapters::SQLiteAdapter.new(db, logger)
      end

      # Establishes a connection to the database that's used by all Active Record objects
      def sqlite_connection(config) # :nodoc:
        parse_config!(config)

        unless self.class.const_defined?(:SQLite)
          require_library_or_gem(config[:adapter])

          db = SQLite::Database.new(config[:database], 0)
          db.show_datatypes   = "ON" if !defined? SQLite::Version
          db.results_as_hash  = true if defined? SQLite::Version
          db.type_translation = false

          # "Downgrade" deprecated sqlite API
          if SQLite.const_defined?(:Version)
            ConnectionAdapters::SQLite2Adapter.new(db, logger)
          else
            ConnectionAdapters::DeprecatedSQLiteAdapter.new(db, logger)
          end
        end
      end

      private
        def parse_config!(config)
          config[:database] ||= config[:dbfile]
          # Require database.
          unless config[:database]
            raise ArgumentError, "No database file specified. Missing argument: database"
          end

          # Allow database path relative to RAILS_ROOT, but only if
          # the database path is not the special path that tells
          # Sqlite build a database only in memory.
          if Object.const_defined?(:RAILS_ROOT) && ':memory:' != config[:database]
            config[:database] = File.expand_path(config[:database], RAILS_ROOT)
          end
        end
    end
  end

  module ConnectionAdapters #:nodoc:
    class SQLiteColumn < Column #:nodoc:
      class <<  self
        def string_to_binary(value)
          value.gsub(/\0|\%/) do |b|
            case b
              when "\0" then "%00"
              when "%"  then "%25"
            end
          end                
        end
        
        def binary_to_string(value)
          value.gsub(/%00|%25/) do |b|
            case b
              when "%00" then "\0"
              when "%25" then "%"
            end
          end                
        end
      end
    end

    # The SQLite adapter works with both the 2.x and 3.x series of SQLite with the sqlite-ruby drivers (available both as gems and
    # from http://rubyforge.org/projects/sqlite-ruby/).
    #
    # Options:
    #
    # * <tt>:database</tt> -- Path to the database file.
    class SQLiteAdapter < AbstractAdapter
      def adapter_name #:nodoc:
        'SQLite'
      end

      def supports_migrations? #:nodoc:
        true
      end
      
      def supports_count_distinct? #:nodoc:
        false
      end

      def native_database_types #:nodoc:
        {
          :primary_key => "INTEGER PRIMARY KEY NOT NULL",
          :string      => { :name => "varchar", :limit => 255 },
          :text        => { :name => "text" },
          :integer     => { :name => "integer" },
          :float       => { :name => "float" },
          :decimal     => { :name => "decimal" },
          :datetime    => { :name => "datetime" },
          :timestamp   => { :name => "datetime" },
          :time        => { :name => "datetime" },
          :date        => { :name => "date" },
          :binary      => { :name => "blob" },
          :boolean     => { :name => "boolean" }
        }
      end


      # QUOTING ==================================================

      def quote_string(s) #:nodoc:
        @connection.class.quote(s)
      end

      def quote_column_name(name) #:nodoc:
        %Q("#{name}")
      end


      # DATABASE STATEMENTS ======================================

      def execute(sql, name = nil) #:nodoc:
        catch_schema_changes { log(sql, name) { @connection.execute(sql) } }
      end

      def update(sql, name = nil) #:nodoc:
        execute(sql, name)
        @connection.changes
      end

      def delete(sql, name = nil) #:nodoc:
        sql += " WHERE 1=1" unless sql =~ /WHERE/i
        execute(sql, name)
        @connection.changes
      end

      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
        execute(sql, name = nil)
        id_value || @connection.last_insert_row_id
      end

      def select_all(sql, name = nil) #:nodoc:
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

      def select_one(sql, name = nil) #:nodoc:
        result = select_all(sql, name)
        result.nil? ? nil : result.first
      end


      def begin_db_transaction #:nodoc:
        catch_schema_changes { @connection.transaction }
      end
      
      def commit_db_transaction #:nodoc:
        catch_schema_changes { @connection.commit }
      end

      def rollback_db_transaction #:nodoc:
        catch_schema_changes { @connection.rollback }
      end


      # SELECT ... FOR UPDATE is redundant since the table is locked.
      def add_lock!(sql, options) #:nodoc:
        sql
      end


      # SCHEMA STATEMENTS ========================================

      def tables(name = nil) #:nodoc:
        execute("SELECT name FROM sqlite_master WHERE type = 'table'", name).map do |row|
          row[0]
        end
      end

      def columns(table_name, name = nil) #:nodoc:
        table_structure(table_name).map do |field|
          SQLiteColumn.new(field['name'], field['dflt_value'], field['type'], field['notnull'] == "0")
        end
      end

      def indexes(table_name, name = nil) #:nodoc:
        execute("PRAGMA index_list(#{table_name})", name).map do |row|
          index = IndexDefinition.new(table_name, row['name'])
          index.unique = row['unique'] != '0'
          index.columns = execute("PRAGMA index_info('#{index.name}')").map { |col| col['name'] }
          index
        end
      end

      def primary_key(table_name) #:nodoc:
        column = table_structure(table_name).find {|field| field['pk'].to_i == 1}
        column ? column['name'] : nil
      end

      def remove_index(table_name, options={}) #:nodoc:
        execute "DROP INDEX #{quote_column_name(index_name(table_name, options))}"
      end
      
      def rename_table(name, new_name)
        execute "ALTER TABLE #{name} RENAME TO #{new_name}"
      end

      def add_column(table_name, column_name, type, options = {}) #:nodoc:
        super(table_name, column_name, type, options)
        # See last paragraph on http://www.sqlite.org/lang_altertable.html
        execute "VACUUM"
      end
      
      def remove_column(table_name, column_name) #:nodoc:
        alter_table(table_name) do |definition|
          definition.columns.delete(definition[column_name])
        end
      end
      
      def change_column_default(table_name, column_name, default) #:nodoc:
        alter_table(table_name) do |definition|
          definition[column_name].default = default
        end
      end

      def change_column(table_name, column_name, type, options = {}) #:nodoc:
        alter_table(table_name) do |definition|
          definition[column_name].instance_eval do
            self.type    = type
            self.limit   = options[:limit] if options[:limit]
            self.default = options[:default] unless options[:default].nil?
          end
        end
      end

      def rename_column(table_name, column_name, new_column_name) #:nodoc:
        alter_table(table_name, :rename => {column_name => new_column_name})
      end
          

      protected
        def table_structure(table_name)
          returning structure = execute("PRAGMA table_info(#{table_name})") do
            raise ActiveRecord::StatementInvalid if structure.empty?
          end
        end
        
        def alter_table(table_name, options = {}) #:nodoc:
          altered_table_name = "altered_#{table_name}"
          caller = lambda {|definition| yield definition if block_given?}

          transaction do
            move_table(table_name, altered_table_name, 
              options.merge(:temporary => true))
            move_table(altered_table_name, table_name, &caller)
          end
        end
        
        def move_table(from, to, options = {}, &block) #:nodoc:
          copy_table(from, to, options, &block)
          drop_table(from)
        end
        
        def copy_table(from, to, options = {}) #:nodoc:
          create_table(to, options) do |@definition|
            columns(from).each do |column|
              column_name = options[:rename] ?
                (options[:rename][column.name] ||
                 options[:rename][column.name.to_sym] ||
                 column.name) : column.name

              @definition.column(column_name, column.type, 
                :limit => column.limit, :default => column.default,
                :null => column.null)
            end
            @definition.primary_key(primary_key(from))
            yield @definition if block_given?
          end
          
          copy_table_indexes(from, to)
          copy_table_contents(from, to, 
            @definition.columns.map {|column| column.name}, 
            options[:rename] || {})
        end
        
        def copy_table_indexes(from, to) #:nodoc:
          indexes(from).each do |index|
            name = index.name
            if to == "altered_#{from}"
              name = "temp_#{name}"
            elsif from == "altered_#{to}"
              name = name[5..-1]
            end
            
            # index name can't be the same
            opts = { :name => name.gsub(/_(#{from})_/, "_#{to}_") }
            opts[:unique] = true if index.unique
            add_index(to, index.columns, opts)
          end
        end
        
        def copy_table_contents(from, to, columns, rename = {}) #:nodoc:
          column_mappings = Hash[*columns.map {|name| [name, name]}.flatten]
          rename.inject(column_mappings) {|map, a| map[a.last] = a.first; map}
          from_columns = columns(from).collect {|col| col.name}
          columns = columns.find_all{|col| from_columns.include?(column_mappings[col])}
          @connection.execute "SELECT * FROM #{from}" do |row|
            sql = "INSERT INTO #{to} ("+columns*','+") VALUES ("            
            sql << columns.map {|col| quote row[column_mappings[col]]} * ', '
            sql << ')'
            @connection.execute sql
          end
        end
        
        def catch_schema_changes
          return yield
        rescue ActiveRecord::StatementInvalid => exception
          if exception.message =~ /database schema has changed/
            reconnect!
            retry
          else
            raise
          end
        end
    end
    
    class SQLite2Adapter < SQLiteAdapter # :nodoc:
      # SQLite 2 does not support COUNT(DISTINCT) queries:
      #
      #   select COUNT(DISTINCT ArtistID) from CDs;    
      #
      # In order to get  the number of artists we execute the following statement
      # 
      #   SELECT COUNT(ArtistID) FROM (SELECT DISTINCT ArtistID FROM CDs);
      def execute(sql, name = nil) #:nodoc:
        super(rewrite_count_distinct_queries(sql), name)
      end
      
      def rewrite_count_distinct_queries(sql)
        if sql =~ /count\(distinct ([^\)]+)\)( AS \w+)? (.*)/i
          distinct_column = $1
          distinct_query  = $3
          column_name     = distinct_column.split('.').last
          "SELECT COUNT(#{column_name}) FROM (SELECT DISTINCT #{distinct_column} #{distinct_query})"
        else
          sql
        end
      end
      
      def rename_table(name, new_name)
        move_table(name, new_name)
      end
      
      def add_column(table_name, column_name, type, options = {}) #:nodoc:
        alter_table(table_name) do |definition|
          definition.column(column_name, type, options)
        end
      end
      
    end

    class DeprecatedSQLiteAdapter < SQLite2Adapter # :nodoc:
      def insert(sql, name = nil, pk = nil, id_value = nil)
        execute(sql, name = nil)
        id_value || @connection.last_insert_rowid
      end
    end
  end
end
