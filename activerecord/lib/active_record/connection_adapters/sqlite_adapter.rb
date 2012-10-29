require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/statement_pool'
require 'active_support/core_ext/string/encoding'
require 'arel/visitors/bind_visitor'

module ActiveRecord
  module ConnectionAdapters #:nodoc:
    class SQLiteColumn < Column #:nodoc:
      class <<  self
        def binary_to_string(value)
          if value.respond_to?(:force_encoding) && value.encoding != Encoding::ASCII_8BIT
            value = value.force_encoding(Encoding::ASCII_8BIT)
          end
          value
        end
      end
    end

    # The SQLite adapter works with both the 2.x and 3.x series of SQLite with the sqlite-ruby
    # drivers (available both as gems and from http://rubyforge.org/projects/sqlite-ruby/).
    #
    # Options:
    #
    # * <tt>:database</tt> - Path to the database file.
    class SQLiteAdapter < AbstractAdapter
      class Version
        include Comparable

        def initialize(version_string)
          @version = version_string.split('.').map { |v| v.to_i }
        end

        def <=>(version_string)
          @version <=> version_string.split('.').map { |v| v.to_i }
        end
      end

      class StatementPool < ConnectionAdapters::StatementPool
        def initialize(connection, max)
          super
          @cache = Hash.new { |h,pid| h[pid] = {} }
        end

        def each(&block); cache.each(&block); end
        def key?(key);    cache.key?(key); end
        def [](key);      cache[key]; end
        def length;       cache.length; end

        def []=(sql, key)
          while @max <= cache.size
            dealloc(cache.shift.last[:stmt])
          end
          cache[sql] = key
        end

        def clear
          cache.values.each do |hash|
            dealloc hash[:stmt]
          end
          cache.clear
        end

        private
        def cache
          @cache[$$]
        end

        def dealloc(stmt)
          stmt.close unless stmt.closed?
        end
      end

      class BindSubstitution < Arel::Visitors::SQLite # :nodoc:
        include Arel::Visitors::BindVisitor
      end

      def initialize(connection, logger, config)
        super(connection, logger)
        @statements = StatementPool.new(@connection,
                                        config.fetch(:statement_limit) { 1000 })
        @config = config

        if config.fetch(:prepared_statements) { true }
          @visitor = Arel::Visitors::SQLite.new self
        else
          @visitor = BindSubstitution.new self
        end
      end

      def adapter_name #:nodoc:
        'SQLite'
      end

      # Returns true if SQLite version is '2.0.0' or greater, false otherwise.
      def supports_ddl_transactions?
        sqlite_version >= '2.0.0'
      end

      # Returns true if SQLite version is '3.6.8' or greater, false otherwise.
      def supports_savepoints?
        sqlite_version >= '3.6.8'
      end

      # Returns true, since this connection adapter supports prepared statement
      # caching.
      def supports_statement_cache?
        true
      end

      # Returns true, since this connection adapter supports migrations.
      def supports_migrations? #:nodoc:
        true
      end

      # Returns true.
      def supports_primary_key? #:nodoc:
        true
      end

      # Returns true.
      def supports_explain?
        true
      end

      def requires_reloading?
        true
      end

      # Returns true if SQLite version is '3.1.6' or greater, false otherwise.
      def supports_add_column?
        sqlite_version >= '3.1.6'
      end

      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        super
        clear_cache!
        @connection.close rescue nil
      end

      # Clears the prepared statements cache.
      def clear_cache!
        @statements.clear
      end

      # Returns true if SQLite version is '3.2.6' or greater, false otherwise.
      def supports_count_distinct? #:nodoc:
        sqlite_version >= '3.2.6'
      end

      # Returns true if SQLite version is '3.1.0' or greater, false otherwise.
      def supports_autoincrement? #:nodoc:
        sqlite_version >= '3.1.0'
      end

      def supports_index_sort_order?
        sqlite_version >= '3.3.0'
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
        %Q("#{name.to_s.gsub('"', '""')}")
      end

      # Quote date/time values for use in SQL input. Includes microseconds
      # if the value is a Time responding to usec.
      def quoted_date(value) #:nodoc:
        if value.respond_to?(:usec)
          "#{super}.#{sprintf("%06d", value.usec)}"
        else
          super
        end
      end

      if "<3".encoding_aware?
        def type_cast(value, column) # :nodoc:
          return value.to_f if BigDecimal === value
          return super unless String === value
          return super unless column && value

          value = super
          if column.type == :string && value.encoding == Encoding::ASCII_8BIT
            logger.error "Binary data inserted for `string` type on column `#{column.name}`" if logger
            value = value.encode Encoding::UTF_8
          end
          value
        end
      else
        def type_cast(value, column) # :nodoc:
          return super unless BigDecimal === value

          value.to_f
        end
      end

      # DATABASE STATEMENTS ======================================

      def explain(arel, binds = [])
        sql = "EXPLAIN QUERY PLAN #{to_sql(arel, binds)}"
        ExplainPrettyPrinter.new.pp(exec_query(sql, 'EXPLAIN', binds))
      end

      class ExplainPrettyPrinter
        # Pretty prints the result of a EXPLAIN QUERY PLAN in a way that resembles
        # the output of the SQLite shell:
        #
        #   0|0|0|SEARCH TABLE users USING INTEGER PRIMARY KEY (rowid=?) (~1 rows)
        #   0|1|1|SCAN TABLE posts (~100000 rows)
        #
        def pp(result) # :nodoc:
          result.rows.map do |row|
            row.join('|')
          end.join("\n") + "\n"
        end
      end

      def exec_query(sql, name = nil, binds = [])
        log(sql, name, binds) do

          # Don't cache statements without bind values
          if binds.empty?
            stmt    = @connection.prepare(sql)
            cols    = stmt.columns
            records = stmt.to_a
            stmt.close
            stmt = records
          else
            cache = @statements[sql] ||= {
              :stmt => @connection.prepare(sql)
            }
            stmt = cache[:stmt]
            cols = cache[:cols] ||= stmt.columns
            stmt.reset!
            stmt.bind_params binds.map { |col, val|
              type_cast(val, col)
            }
          end

          ActiveRecord::Result.new(cols, stmt.to_a)
        end
      end

      def exec_delete(sql, name = 'SQL', binds = [])
        exec_query(sql, name, binds)
        @connection.changes
      end
      alias :exec_update :exec_delete

      def last_inserted_id(result)
        @connection.last_insert_row_id
      end

      def execute(sql, name = nil) #:nodoc:
        log(sql, name) { @connection.execute(sql) }
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
        super
        id_value || @connection.last_insert_row_id
      end
      alias :create :insert_sql

      def select_rows(sql, name = nil)
        exec_query(sql, name).rows
      end

      def create_savepoint
        execute("SAVEPOINT #{current_savepoint_name}")
      end

      def rollback_to_savepoint
        execute("ROLLBACK TO SAVEPOINT #{current_savepoint_name}")
      end

      def release_savepoint
        execute("RELEASE SAVEPOINT #{current_savepoint_name}")
      end

      def begin_db_transaction #:nodoc:
        log('begin transaction',nil) { @connection.transaction }
      end

      def commit_db_transaction #:nodoc:
        log('commit transaction',nil) { @connection.commit }
      end

      def rollback_db_transaction #:nodoc:
        log('rollback transaction',nil) { @connection.rollback }
      end

      # SCHEMA STATEMENTS ========================================

      def tables(name = 'SCHEMA', table_name = nil) #:nodoc:
        sql = <<-SQL
          SELECT name
          FROM sqlite_master
          WHERE type = 'table' AND NOT name = 'sqlite_sequence'
        SQL
        sql << " AND name = #{quote_table_name(table_name)}" if table_name

        exec_query(sql, name).map do |row|
          row['name']
        end
      end

      def table_exists?(name)
        name && tables('SCHEMA', name).any?
      end

      # Returns an array of +SQLiteColumn+ objects for the table specified by +table_name+.
      def columns(table_name, name = nil) #:nodoc:
        table_structure(table_name).map do |field|
          case field["dflt_value"]
          when /^null$/i
            field["dflt_value"] = nil
          when /^'(.*)'$/
            field["dflt_value"] = $1.gsub(/''/, "'")
          when /^"(.*)"$/
            field["dflt_value"] = $1.gsub(/""/, '"')
          end

          SQLiteColumn.new(field['name'], field['dflt_value'], field['type'], field['notnull'].to_i == 0)
        end
      end

      # Returns an array of indexes for the given table.
      def indexes(table_name, name = nil) #:nodoc:
        exec_query("PRAGMA index_list(#{quote_table_name(table_name)})", 'SCHEMA').map do |row|
          IndexDefinition.new(
            table_name,
            row['name'],
            row['unique'] != 0,
            exec_query("PRAGMA index_info('#{row['name']}')", 'SCHEMA').map { |col|
              col['name']
            })
        end
      end

      def primary_key(table_name) #:nodoc:
        column = table_structure(table_name).find { |field|
          field['pk'] == 1
        }
        column && column['name']
      end

      def remove_index!(table_name, index_name) #:nodoc:
        exec_query "DROP INDEX #{quote_column_name(index_name)}"
      end

      # Renames a table.
      #
      # Example:
      #   rename_table('octopuses', 'octopi')
      def rename_table(name, new_name)
        exec_query "ALTER TABLE #{quote_table_name(name)} RENAME TO #{quote_table_name(new_name)}"
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
        raise ArgumentError.new("You must specify at least one column name. Example: remove_column(:people, :first_name)") if column_names.empty?

        if column_names.flatten!
          message = 'Passing array to remove_columns is deprecated, please use ' +
                    'multiple arguments, like: `remove_columns(:posts, :foo, :bar)`'
          ActiveSupport::Deprecation.warn message, caller
        end

        column_names.each do |column_name|
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
          exec_query("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
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
            self.precision = options[:precision] if options.include?(:precision)
            self.scale   = options[:scale] if options.include?(:scale)
          end
        end
      end

      def rename_column(table_name, column_name, new_column_name) #:nodoc:
        unless columns(table_name).detect{|c| c.name == column_name.to_s }
          raise ActiveRecord::ActiveRecordError, "Missing column #{table_name}.#{column_name}"
        end
        alter_table(table_name, :rename => {column_name.to_s => new_column_name.to_s})
      end

      def empty_insert_statement_value
        "VALUES(NULL)"
      end

      protected
        def select(sql, name = nil, binds = []) #:nodoc:
          exec_query(sql, name, binds).to_a
        end

        def table_structure(table_name)
          structure = exec_query("PRAGMA table_info(#{quote_table_name(table_name)})", 'SCHEMA').to_hash
          raise(ActiveRecord::StatementInvalid, "Could not find table '#{table_name}'") if structure.empty?
          structure
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
                :precision => column.precision, :scale => column.scale,
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

            to_column_names = columns(to).map { |c| c.name }
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
          column_mappings = Hash[columns.map {|name| [name, name]}]
          rename.each { |a| column_mappings[a.last] = a.first }
          from_columns = columns(from).collect {|col| col.name}
          columns = columns.find_all{|col| from_columns.include?(column_mappings[col])}
          quoted_columns = columns.map { |col| quote_column_name(col) } * ','

          quoted_to = quote_table_name(to)
          exec_query("SELECT * FROM #{quote_table_name(from)}").each do |row|
            sql = "INSERT INTO #{quoted_to} (#{quoted_columns}) VALUES ("
            sql << columns.map {|col| quote row[column_mappings[col]]} * ', '
            sql << ')'
            exec_query sql
          end
        end

        def sqlite_version
          @sqlite_version ||= SQLiteAdapter::Version.new(select_value('select sqlite_version(*)'))
        end

        def default_primary_key_type
          if supports_autoincrement?
            'INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL'
          else
            'INTEGER PRIMARY KEY NOT NULL'
          end
        end

        def translate_exception(exception, message)
          case exception.message
          when /column(s)? .* (is|are) not unique/
            RecordNotUnique.new(message, exception)
          else
            super
          end
        end

    end
  end
end
