# encoding: binary
require 'active_record/connection_adapters/abstract_adapter'

module ActiveRecord
  class Base
    class << self
      # Establishes a connection to the database that's used by all Active Record objects
      def sqlite_connection(config) # :nodoc:
        parse_sqlite_config!(config)

        unless self.class.const_defined?(:SQLite)
          require_library_or_gem(config[:adapter])

          db = SQLite::Database.new(config[:database], 0)
          db.show_datatypes   = "ON" if !defined? SQLite::Version
          db.results_as_hash  = true if defined? SQLite::Version
          db.type_translation = false

          message = "Support for SQLite2Adapter and DeprecatedSQLiteAdapter has been removed from Rails 3. "
          message << "You should migrate to SQLite 3+ or use the plugin from git://github.com/rails/sqlite2_adapter.git with Rails 3."
          ActiveSupport::Deprecation.warn(message)

          # "Downgrade" deprecated sqlite API
          if SQLite.const_defined?(:Version)
            ConnectionAdapters::SQLite2Adapter.new(db, logger, config)
          else
            ConnectionAdapters::DeprecatedSQLiteAdapter.new(db, logger, config)
          end
        end
      end

      private
        def parse_sqlite_config!(config)
          if config.include?(:dbfile)
            ActiveSupport::Deprecation.warn "Please update config/database.yml to use 'database' instead of 'dbfile'"
          end

          config[:database] ||= config[:dbfile]
          # Require database.
          unless config[:database]
            raise ArgumentError, "No database file specified. Missing argument: database"
          end

          # Allow database path relative to RAILS_ROOT, but only if
          # the database path is not the special path that tells
          # Sqlite to build a database only in memory.
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
          value = value.dup.force_encoding(Encoding::BINARY) if value.respond_to?(:force_encoding)
          value.gsub(/\0|\%/n) do |b|
            case b
              when "\0" then "%00"
              when "%"  then "%25"
            end
          end
        end

        def binary_to_string(value)
          value = value.dup.force_encoding(Encoding::BINARY) if value.respond_to?(:force_encoding)
          value.gsub(/%00|%25/n) do |b|
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
    # * <tt>:database</tt> - Path to the database file.
    class SQLiteAdapter < AbstractAdapter
      class Version
        include Comparable

        def initialize(version_string)
          @version = version_string.split('.').map(&:to_i)
        end

        def <=>(version_string)
          @version <=> version_string.split('.').map(&:to_i)
        end
      end

      def initialize(connection, logger, config)
        super(connection, logger)
        @config = config
      end

      def adapter_name #:nodoc:
        'SQLite'
      end

      def supports_ddl_transactions?
        sqlite_version >= '2.0.0'
      end

      def supports_migrations? #:nodoc:
        true
      end

      def supports_primary_key? #:nodoc:
        true
      end

      def requires_reloading?
        true
      end

      def supports_add_column?
        sqlite_version >= '3.1.6'
      end
 
      def disconnect!
        super
        @connection.close rescue nil
      end

      def supports_count_distinct? #:nodoc:
        sqlite_version >= '3.2.6'
      end

      def supports_autoincrement? #:nodoc:
        sqlite_version >= '3.1.0'
      end

      def native_database_types #:nodoc:
        {
          :primary_key => default_primary_key_type,
          :string      => { :name => "varchar", :limit => 255 },
          :text        => { :name => "text" },
          :integer     => { :name => "integer" },
          :float       => { :name => "float" },
          :decimal     => { :name => "decimal" },
          :datetime    => { :name => "datetime" },
          :timestamp   => { :name => "datetime" },
          :time        => { :name => "time" },
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

      def update_sql(sql, name = nil) #:nodoc:
        super
        @connection.changes
      end

      def delete_sql(sql, name = nil) #:nodoc:
        sql += " WHERE 1=1" unless sql =~ /WHERE/i
        super sql, name
      end

      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
        super || @connection.last_insert_row_id
      end

      def select_rows(sql, name = nil)
        execute(sql, name).map do |row|
          (0...(row.size / 2)).map { |i| row[i] }
        end
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
        sql = <<-SQL
          SELECT name
          FROM sqlite_master
          WHERE type = 'table' AND NOT name = 'sqlite_sequence'
        SQL

        execute(sql, name).map do |row|
          row[0]
        end
      end

      def columns(table_name, name = nil) #:nodoc:
        table_structure(table_name).map do |field|
          SQLiteColumn.new(field['name'], field['dflt_value'], field['type'], field['notnull'] == "0")
        end
      end

      def indexes(table_name, name = nil) #:nodoc:
        execute("PRAGMA index_list(#{quote_table_name(table_name)})", name).map do |row|
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

      # See: http://www.sqlite.org/lang_altertable.html
      # SQLite has an additional restriction on the ALTER TABLE statement
      def valid_alter_table_options( type, options)
        type.to_sym != :primary_key
      end

      def add_column(table_name, column_name, type, options = {}) #:nodoc:
        if supports_add_column? && valid_alter_table_options( type, options )
          super(table_name, column_name, type, options)
        else
          alter_table(table_name) do |definition|
            definition.column(column_name, type, options)
          end
        end
      end

      def remove_column(table_name, *column_names) #:nodoc:
        column_names.flatten.each do |column_name|
          alter_table(table_name) do |definition|
            definition.columns.delete(definition[column_name])
          end
        end
      end
      alias :remove_columns :remove_column

      def change_column_default(table_name, column_name, default) #:nodoc:
        alter_table(table_name) do |definition|
          definition[column_name].default = default
        end
      end

      def change_column_null(table_name, column_name, null, default = nil)
        unless null || default.nil?
          execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
        end
        alter_table(table_name) do |definition|
          definition[column_name].null = null
        end
      end

      def change_column(table_name, column_name, type, options = {}) #:nodoc:
        alter_table(table_name) do |definition|
          include_default = options_include_default?(options)
          definition[column_name].instance_eval do
            self.type    = type
            self.limit   = options[:limit] if options.include?(:limit)
            self.default = options[:default] if include_default
            self.null    = options[:null] if options.include?(:null)
          end
        end
      end

      def rename_column(table_name, column_name, new_column_name) #:nodoc:
        unless columns(table_name).detect{|c| c.name == column_name.to_s }
          raise ActiveRecord::ActiveRecordError, "Missing column #{table_name}.#{column_name}"
        end
        alter_table(table_name, :rename => {column_name.to_s => new_column_name.to_s})
      end

      def empty_insert_statement(table_name)
        "INSERT INTO #{table_name} VALUES(NULL)"
      end

      protected
        def select(sql, name = nil) #:nodoc:
          execute(sql, name).map do |row|
            record = {}
            row.each_key do |key|
              if key.is_a?(String)
                record[key.sub(/^"?\w+"?\./, '')] = row[key]
              end
            end
            record
          end
        end

        def table_structure(table_name)
          returning structure = execute("PRAGMA table_info(#{quote_table_name(table_name)})") do
            raise(ActiveRecord::StatementInvalid, "Could not find table '#{table_name}'") if structure.empty?
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
          options = options.merge(:id => (!columns(from).detect{|c| c.name == 'id'}.nil? && 'id' == primary_key(from).to_s))
          create_table(to, options) do |definition|
            @definition = definition
            columns(from).each do |column|
              column_name = options[:rename] ?
                (options[:rename][column.name] ||
                 options[:rename][column.name.to_sym] ||
                 column.name) : column.name
              
              @definition.column(column_name, column.type,
                :limit => column.limit, :default => column.default,
                :null => column.null)
            end
            @definition.primary_key(primary_key(from)) if primary_key(from)
            yield @definition if block_given?
          end

          copy_table_indexes(from, to, options[:rename] || {})
          copy_table_contents(from, to,
            @definition.columns.map {|column| column.name},
            options[:rename] || {})
        end

        def copy_table_indexes(from, to, rename = {}) #:nodoc:
          indexes(from).each do |index|
            name = index.name
            if to == "altered_#{from}"
              name = "temp_#{name}"
            elsif from == "altered_#{to}"
              name = name[5..-1]
            end

            to_column_names = columns(to).map(&:name)
            columns = index.columns.map {|c| rename[c] || c }.select do |column|
              to_column_names.include?(column)
            end

            unless columns.empty?
              # index name can't be the same
              opts = { :name => name.gsub(/_(#{from})_/, "_#{to}_") }
              opts[:unique] = true if index.unique
              add_index(to, columns, opts)
            end
          end
        end

        def copy_table_contents(from, to, columns, rename = {}) #:nodoc:
          column_mappings = Hash[*columns.map {|name| [name, name]}.flatten]
          rename.inject(column_mappings) {|map, a| map[a.last] = a.first; map}
          from_columns = columns(from).collect {|col| col.name}
          columns = columns.find_all{|col| from_columns.include?(column_mappings[col])}
          quoted_columns = columns.map { |col| quote_column_name(col) } * ','

          quoted_to = quote_table_name(to)
          @connection.execute "SELECT * FROM #{quote_table_name(from)}" do |row|
            sql = "INSERT INTO #{quoted_to} (#{quoted_columns}) VALUES ("
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

        def sqlite_version
          @sqlite_version ||= SQLiteAdapter::Version.new(select_value('select sqlite_version(*)'))
        end

        def default_primary_key_type
          if supports_autoincrement?
            'INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL'.freeze
          else
            'INTEGER PRIMARY KEY NOT NULL'.freeze
          end
        end
    end

    class SQLite2Adapter < SQLiteAdapter # :nodoc:
      def rename_table(name, new_name)
        move_table(name, new_name)
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
