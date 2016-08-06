require "active_record/connection_adapters/abstract_adapter"
require "active_record/connection_adapters/statement_pool"
require "active_record/connection_adapters/sqlite3/explain_pretty_printer"
require "active_record/connection_adapters/sqlite3/quoting"
require "active_record/connection_adapters/sqlite3/schema_creation"

gem "sqlite3", "~> 1.3.6"
require "sqlite3"

module ActiveRecord
  module ConnectionHandling # :nodoc:
    def sqlite3_connection(config)
      # Require database.
      unless config[:database]
        raise ArgumentError, "No database file specified. Missing argument: database"
      end

      # Allow database path relative to Rails.root, but only if the database
      # path is not the special path that tells sqlite to build a database only
      # in memory.
      if ":memory:" != config[:database]
        config[:database] = File.expand_path(config[:database], Rails.root) if defined?(Rails.root)
        dirname = File.dirname(config[:database])
        Dir.mkdir(dirname) unless File.directory?(dirname)
      end

      db = SQLite3::Database.new(
        config[:database].to_s,
        results_as_hash: true
      )

      db.busy_timeout(ConnectionAdapters::SQLite3Adapter.type_cast_config_to_integer(config[:timeout])) if config[:timeout]

      ConnectionAdapters::SQLite3Adapter.new(db, logger, nil, config)
    rescue Errno::ENOENT => error
      if error.message.include?("No such file or directory")
        raise ActiveRecord::NoDatabaseError
      else
        raise
      end
    end
  end

  module ConnectionAdapters #:nodoc:
    # The SQLite3 adapter works SQLite 3.6.16 or newer
    # with the sqlite3-ruby drivers (available as gem from https://rubygems.org/gems/sqlite3).
    #
    # Options:
    #
    # * <tt>:database</tt> - Path to the database file.
    class SQLite3Adapter < AbstractAdapter
      ADAPTER_NAME = "SQLite".freeze

      include SQLite3::Quoting

      NATIVE_DATABASE_TYPES = {
        primary_key:  "INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL",
        string:       { name: "varchar" },
        text:         { name: "text" },
        integer:      { name: "integer" },
        float:        { name: "float" },
        decimal:      { name: "decimal" },
        datetime:     { name: "datetime" },
        time:         { name: "time" },
        date:         { name: "date" },
        binary:       { name: "blob" },
        boolean:      { name: "boolean" }
      }

      class StatementPool < ConnectionAdapters::StatementPool
        private

        def dealloc(stmt)
          stmt[:stmt].close unless stmt[:stmt].closed?
        end
      end

      def schema_creation # :nodoc:
        SQLite3::SchemaCreation.new self
      end

      def arel_visitor # :nodoc:
        Arel::Visitors::SQLite.new(self)
      end

      def initialize(connection, logger, connection_options, config)
        super(connection, logger, config)

        @active     = nil
        @statements = StatementPool.new(self.class.type_cast_config_to_integer(config[:statement_limit]))
      end

      def supports_ddl_transactions?
        true
      end

      def supports_savepoints?
        true
      end

      def supports_partial_index?
        sqlite_version >= "3.8.0"
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

      def supports_primary_key? #:nodoc:
        true
      end

      def requires_reloading?
        true
      end

      def supports_views?
        true
      end

      def supports_datetime_with_precision?
        true
      end

      def supports_multi_insert?
        sqlite_version >= "3.7.11"
      end

      def active?
        @active != false
      end

      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        super
        @active = false
        @connection.close rescue nil
      end

      # Clears the prepared statements cache.
      def clear_cache!
        @statements.clear
      end

      def supports_index_sort_order?
        true
      end

      def valid_type?(type)
        true
      end

      # Returns 62. SQLite supports index names up to 64
      # characters. The rest is used by Rails internally to perform
      # temporary rename operations
      def allowed_index_name_length
        index_name_length - 2
      end

      def native_database_types #:nodoc:
        NATIVE_DATABASE_TYPES
      end

      # Returns the current database encoding format as a string, eg: 'UTF-8'
      def encoding
        @connection.encoding.to_s
      end

      def supports_explain?
        true
      end

      #--
      # DATABASE STATEMENTS ======================================
      #++

      def explain(arel, binds = [])
        sql = "EXPLAIN QUERY PLAN #{to_sql(arel, binds)}"
        SQLite3::ExplainPrettyPrinter.new.pp(exec_query(sql, "EXPLAIN", []))
      end

      def exec_query(sql, name = nil, binds = [], prepare: false)
        type_casted_binds = type_casted_binds(binds)

        log(sql, name, binds, type_casted_binds) do
          # Don't cache statements if they are not prepared
          unless prepare
            stmt    = @connection.prepare(sql)
            begin
              cols    = stmt.columns
              unless without_prepared_statement?(binds)
                stmt.bind_params(type_casted_binds)
              end
              records = stmt.to_a
            ensure
              stmt.close
            end
          else
            cache = @statements[sql] ||= {
              stmt: @connection.prepare(sql)
            }
            stmt = cache[:stmt]
            cols = cache[:cols] ||= stmt.columns
            stmt.reset!
            stmt.bind_params(type_casted_binds)
            records = stmt.to_a
          end

          ActiveRecord::Result.new(cols, records)
        end
      end

      def exec_delete(sql, name = "SQL", binds = [])
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

      def begin_db_transaction #:nodoc:
        log("begin transaction",nil) { @connection.transaction }
      end

      def commit_db_transaction #:nodoc:
        log("commit transaction",nil) { @connection.commit }
      end

      def exec_rollback_db_transaction #:nodoc:
        log("rollback transaction",nil) { @connection.rollback }
      end

      # SCHEMA STATEMENTS ========================================

      def tables(name = nil) # :nodoc:
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          #tables currently returns both tables and views.
          This behavior is deprecated and will be changed with Rails 5.1 to only return tables.
          Use #data_sources instead.
        MSG

        if name
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            Passing arguments to #tables is deprecated without replacement.
          MSG
        end

        data_sources
      end

      def data_sources
        select_values("SELECT name FROM sqlite_master WHERE type IN ('table','view') AND name <> 'sqlite_sequence'", "SCHEMA")
      end

      def table_exists?(table_name)
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          #table_exists? currently checks both tables and views.
          This behavior is deprecated and will be changed with Rails 5.1 to only check tables.
          Use #data_source_exists? instead.
        MSG

        data_source_exists?(table_name)
      end

      def data_source_exists?(table_name)
        return false unless table_name.present?

        sql = "SELECT name FROM sqlite_master WHERE type IN ('table','view') AND name <> 'sqlite_sequence'"
        sql << " AND name = #{quote(table_name)}"

        select_values(sql, "SCHEMA").any?
      end

      def views # :nodoc:
        select_values("SELECT name FROM sqlite_master WHERE type = 'view' AND name <> 'sqlite_sequence'", "SCHEMA")
      end

      def view_exists?(view_name) # :nodoc:
        return false unless view_name.present?

        sql = "SELECT name FROM sqlite_master WHERE type = 'view' AND name <> 'sqlite_sequence'"
        sql << " AND name = #{quote(view_name)}"

        select_values(sql, "SCHEMA").any?
      end

      # Returns an array of +Column+ objects for the table specified by +table_name+.
      def columns(table_name) # :nodoc:
        table_name = table_name.to_s
        table_structure(table_name).map do |field|
          case field["dflt_value"]
          when /^null$/i
            field["dflt_value"] = nil
          when /^'(.*)'$/m
            field["dflt_value"] = $1.gsub("''", "'")
          when /^"(.*)"$/m
            field["dflt_value"] = $1.gsub('""', '"')
          end

          collation = field["collation"]
          sql_type = field["type"]
          type_metadata = fetch_type_metadata(sql_type)
          new_column(field["name"], field["dflt_value"], type_metadata, field["notnull"].to_i == 0, table_name, nil, collation)
        end
      end

      # Returns an array of indexes for the given table.
      def indexes(table_name, name = nil) #:nodoc:
        exec_query("PRAGMA index_list(#{quote_table_name(table_name)})", "SCHEMA").map do |row|
          sql = <<-SQL
            SELECT sql
            FROM sqlite_master
            WHERE name=#{quote(row['name'])} AND type='index'
            UNION ALL
            SELECT sql
            FROM sqlite_temp_master
            WHERE name=#{quote(row['name'])} AND type='index'
          SQL
          index_sql = exec_query(sql).first["sql"]
          match = /\sWHERE\s+(.+)$/i.match(index_sql)
          where = match[1] if match
          IndexDefinition.new(
            table_name,
            row["name"],
            row["unique"] != 0,
            exec_query("PRAGMA index_info('#{row['name']}')", "SCHEMA").map { |col|
              col["name"]
            }, nil, nil, where)
        end
      end

      def primary_keys(table_name) # :nodoc:
        pks = table_structure(table_name).select { |f| f["pk"] > 0 }
        pks.sort_by { |f| f["pk"] }.map { |f| f["name"] }
      end

      def remove_index(table_name, options = {}) #:nodoc:
        index_name = index_name_for_remove(table_name, options)
        exec_query "DROP INDEX #{quote_column_name(index_name)}"
      end

      # Renames a table.
      #
      # Example:
      #   rename_table('octopuses', 'octopi')
      def rename_table(table_name, new_name)
        exec_query "ALTER TABLE #{quote_table_name(table_name)} RENAME TO #{quote_table_name(new_name)}"
        rename_table_indexes(table_name, new_name)
      end

      # See: http://www.sqlite.org/lang_altertable.html
      # SQLite has an additional restriction on the ALTER TABLE statement
      def valid_alter_table_type?(type)
        type.to_sym != :primary_key
      end

      def add_column(table_name, column_name, type, options = {}) #:nodoc:
        if valid_alter_table_type?(type)
          super(table_name, column_name, type, options)
        else
          alter_table(table_name) do |definition|
            definition.column(column_name, type, options)
          end
        end
      end

      def remove_column(table_name, column_name, type = nil, options = {}) #:nodoc:
        alter_table(table_name) do |definition|
          definition.remove_column column_name
        end
      end

      def change_column_default(table_name, column_name, default_or_changes) #:nodoc:
        default = extract_new_default_value(default_or_changes)

        alter_table(table_name) do |definition|
          definition[column_name].default = default
        end
      end

      def change_column_null(table_name, column_name, null, default = nil) #:nodoc:
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
            self.collation = options[:collation] if options.include?(:collation)
          end
        end
      end

      def rename_column(table_name, column_name, new_column_name) #:nodoc:
        column = column_for(table_name, column_name)
        alter_table(table_name, rename: {column.name => new_column_name.to_s})
        rename_column_indexes(table_name, column.name, new_column_name)
      end

      protected

        def table_structure(table_name)
          structure = exec_query("PRAGMA table_info(#{quote_table_name(table_name)})", "SCHEMA")
          raise(ActiveRecord::StatementInvalid, "Could not find table '#{table_name}'") if structure.empty?
          table_structure_with_collation(table_name, structure)
        end

        def alter_table(table_name, options = {}) #:nodoc:
          altered_table_name = "a#{table_name}"
          caller = lambda {|definition| yield definition if block_given?}

          transaction do
            move_table(table_name, altered_table_name,
              options.merge(temporary: true))
            move_table(altered_table_name, table_name, &caller)
          end
        end

        def move_table(from, to, options = {}, &block) #:nodoc:
          copy_table(from, to, options, &block)
          drop_table(from)
        end

        def copy_table(from, to, options = {}) #:nodoc:
          from_primary_key = primary_key(from)
          options[:id] = false
          create_table(to, options) do |definition|
            @definition = definition
            @definition.primary_key(from_primary_key) if from_primary_key.present?
            columns(from).each do |column|
              column_name = options[:rename] ?
                (options[:rename][column.name] ||
                 options[:rename][column.name.to_sym] ||
                 column.name) : column.name
              next if column_name == from_primary_key

              @definition.column(column_name, column.type,
                limit: column.limit, default: column.default,
                precision: column.precision, scale: column.scale,
                null: column.null, collation: column.collation)
            end
            yield @definition if block_given?
          end
          copy_table_indexes(from, to, options[:rename] || {})
          copy_table_contents(from, to,
            @definition.columns.map(&:name),
            options[:rename] || {})
        end

        def copy_table_indexes(from, to, rename = {}) #:nodoc:
          indexes(from).each do |index|
            name = index.name
            if to == "a#{from}"
              name = "t#{name}"
            elsif from == "a#{to}"
              name = name[1..-1]
            end

            to_column_names = columns(to).map(&:name)
            columns = index.columns.map {|c| rename[c] || c }.select do |column|
              to_column_names.include?(column)
            end

            unless columns.empty?
              # index name can't be the same
              opts = { name: name.gsub(/(^|_)(#{from})_/, "\\1#{to}_"), internal: true }
              opts[:unique] = true if index.unique
              add_index(to, columns, opts)
            end
          end
        end

        def copy_table_contents(from, to, columns, rename = {}) #:nodoc:
          column_mappings = Hash[columns.map {|name| [name, name]}]
          rename.each { |a| column_mappings[a.last] = a.first }
          from_columns = columns(from).collect(&:name)
          columns = columns.find_all{|col| from_columns.include?(column_mappings[col])}
          from_columns_to_copy = columns.map { |col| column_mappings[col] }
          quoted_columns = columns.map { |col| quote_column_name(col) } * ","
          quoted_from_columns = from_columns_to_copy.map { |col| quote_column_name(col) } * ","

          exec_query("INSERT INTO #{quote_table_name(to)} (#{quoted_columns})
                     SELECT #{quoted_from_columns} FROM #{quote_table_name(from)}")
        end

        def sqlite_version
          @sqlite_version ||= SQLite3Adapter::Version.new(select_value("select sqlite_version(*)"))
        end

        def translate_exception(exception, message)
          case exception.message
          # SQLite 3.8.2 returns a newly formatted error message:
          #   UNIQUE constraint failed: *table_name*.*column_name*
          # Older versions of SQLite return:
          #   column *column_name* is not unique
          when /column(s)? .* (is|are) not unique/, /UNIQUE constraint failed: .*/
            RecordNotUnique.new(message)
          else
            super
          end
        end

      private
        COLLATE_REGEX = /.*\"(\w+)\".*collate\s+\"(\w+)\".*/i.freeze

        def table_structure_with_collation(table_name, basic_structure)
          collation_hash = {}
          sql            = "SELECT sql FROM
                              (SELECT * FROM sqlite_master UNION ALL
                               SELECT * FROM sqlite_temp_master)
                            WHERE type='table' and name='#{ table_name }' \;"

          # Result will have following sample string
          # CREATE TABLE "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          #                       "password_digest" varchar COLLATE "NOCASE");
          result = exec_query(sql, "SCHEMA").first

          if result
            # Splitting with left parentheses and picking up last will return all
            # columns separated with comma(,).
            columns_string = result["sql"].split("(").last

            columns_string.split(",").each do |column_string|
              # This regex will match the column name and collation type and will save
              # the value in $1 and $2 respectively.
              collation_hash[$1] = $2 if COLLATE_REGEX =~ column_string
            end

            basic_structure.map! do |column|
              column_name = column["name"]

              if collation_hash.has_key? column_name
                column["collation"] = collation_hash[column_name]
              end

              column
            end
          else
            basic_structure.to_hash
          end
        end
    end
  end
end
