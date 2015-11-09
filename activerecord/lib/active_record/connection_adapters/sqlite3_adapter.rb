require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/statement_pool'
require 'active_record/connection_adapters/sqlite3/schema_creation'

gem 'sqlite3', '~> 1.3.6'
require 'sqlite3'

module ActiveRecord
  module ConnectionHandling # :nodoc:
    # sqlite3 adapter reuses sqlite_connection.
    def sqlite3_connection(config)
      # Require database.
      unless config[:database]
        raise ArgumentError, "No database file specified. Missing argument: database"
      end

      # Allow database path relative to Rails.root, but only if the database
      # path is not the special path that tells sqlite to build a database only
      # in memory.
      if ':memory:' != config[:database]
        config[:database] = File.expand_path(config[:database], Rails.root) if defined?(Rails.root)
        dirname = File.dirname(config[:database])
        Dir.mkdir(dirname) unless File.directory?(dirname)
      end

      db = SQLite3::Database.new(
        config[:database].to_s,
        :results_as_hash => true
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
      ADAPTER_NAME = 'SQLite'.freeze
      include Savepoints

      NATIVE_DATABASE_TYPES = {
        primary_key:  'INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL',
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

      def initialize(connection, logger, connection_options, config)
        super(connection, logger, config)

        @active     = nil
        @statements = StatementPool.new(self.class.type_cast_config_to_integer(config.fetch(:statement_limit) { 1000 }))

        @visitor = Arel::Visitors::SQLite.new self
        @quoted_column_names = {}

        if self.class.type_cast_config_to_boolean(config.fetch(:prepared_statements) { true })
          @prepared_statements = true
          @visitor.extend(DetermineIfPreparableVisitor)
        else
          @prepared_statements = false
        end

        execute('PRAGMA foreign_keys = 1')
      end

      def supports_ddl_transactions?
        true
      end

      def supports_savepoints?
        true
      end

      def supports_partial_index?
        sqlite_version >= '3.8.0'
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

      # Returns 62. SQLite supports index names up to 64
      # characters. The rest is used by rails internally to perform
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

      def supports_foreign_keys?
        true
      end

      # QUOTING ==================================================

      def _quote(value) # :nodoc:
        case value
        when Type::Binary::Data
          "x'#{value.hex}'"
        else
          super
        end
      end

      def _type_cast(value) # :nodoc:
        case value
        when BigDecimal
          value.to_f
        when String
          if value.encoding == Encoding::ASCII_8BIT
            super(value.encode(Encoding::UTF_8))
          else
            super
          end
        else
          super
        end
      end

      def quote_string(s) #:nodoc:
        @connection.class.quote(s)
      end

      def quote_table_name_for_assignment(table, attr)
        quote_column_name(attr)
      end

      def quote_column_name(name) #:nodoc:
        @quoted_column_names[name] ||= %Q("#{name.to_s.gsub('"', '""')}")
      end

      #--
      # DATABASE STATEMENTS ======================================
      #++

      def explain(arel, binds = [])
        sql = "EXPLAIN QUERY PLAN #{to_sql(arel, binds)}"
        ExplainPrettyPrinter.new.pp(exec_query(sql, 'EXPLAIN', []))
      end

      class ExplainPrettyPrinter
        # Pretty prints the result of an EXPLAIN QUERY PLAN in a way that resembles
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

      def exec_query(sql, name = nil, binds = [], prepare: false)
        type_casted_binds = binds.map { |attr| type_cast(attr.value_for_database) }

        log(sql, name, binds) do
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
            stmt = records
          else
            cache = @statements[sql] ||= {
              :stmt => @connection.prepare(sql)
            }
            stmt = cache[:stmt]
            cols = cache[:cols] ||= stmt.columns
            stmt.reset!
            stmt.bind_params(type_casted_binds)
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

      def select_rows(sql, name = nil, binds = [])
        exec_query(sql, name, binds).rows
      end

      def begin_db_transaction #:nodoc:
        log('begin transaction',nil) { @connection.transaction }
      end

      def commit_db_transaction #:nodoc:
        log('commit transaction',nil) { @connection.commit }
      end

      def exec_rollback_db_transaction #:nodoc:
        log('rollback transaction',nil) { @connection.rollback }
      end

      # REFERNTIAL INTEGRITY =====================================

      def disable_referential_integrity #:nodoc:
        if select_value("PRAGMA foreign_keys") != 1
          yield
        else
          begin
            execute("PRAGMA foreign_keys = 0")
            if select_value("PRAGMA foreign_keys") != 0
              # SQLite does not support disabling referential integrity within transactions,
              # see https://www.sqlite.org/pragma.html#pragma_foreign_keys
              raise ActiveRecord::StatementInvalid, "Cannot disable referential integrity while a transaction is active"
            end
            yield
          ensure
            execute("PRAGMA foreign_keys = 1")
          end
        end
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
        select_values("SELECT name FROM sqlite_master WHERE type IN ('table','view') AND name <> 'sqlite_sequence'", 'SCHEMA')
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

        select_values(sql, 'SCHEMA').any?
      end

      def views # :nodoc:
        select_values("SELECT name FROM sqlite_master WHERE type = 'view' AND name <> 'sqlite_sequence'", 'SCHEMA')
      end

      def view_exists?(view_name) # :nodoc:
        return false unless view_name.present?

        sql = "SELECT name FROM sqlite_master WHERE type = 'view' AND name <> 'sqlite_sequence'"
        sql << " AND name = #{quote(view_name)}"

        select_values(sql, 'SCHEMA').any?
      end

      # Returns an array of +Column+ objects for the table specified by +table_name+.
      def columns(table_name) #:nodoc:
        table_structure(table_name).map do |field|
          case field["dflt_value"]
          when /^null$/i
            field["dflt_value"] = nil
          when /^'(.*)'$/m
            field["dflt_value"] = $1.gsub("''", "'")
          when /^"(.*)"$/m
            field["dflt_value"] = $1.gsub('""', '"')
          end

          collation = field['collation']
          sql_type = field['type']
          type_metadata = fetch_type_metadata(sql_type)
          new_column(field['name'], field['dflt_value'], type_metadata, field['notnull'].to_i == 0, nil, collation)
        end
      end

      # Returns an array of indexes for the given table.
      def indexes(table_name, name = nil) #:nodoc:
        exec_query("PRAGMA index_list(#{quote_table_name(table_name)})", 'SCHEMA').map do |row|
          sql = "SELECT sql FROM sqlite_master WHERE name=#{quote(row['name'])} AND type='index'"
          index_sql = exec_query(sql).first['sql']
          match = /\sWHERE\s+(.+)$/i.match(index_sql)
          where = match[1] if match
          IndexDefinition.new(
            table_name,
            row['name'],
            row['unique'] != 0,
            exec_query("PRAGMA index_info('#{row['name']}')", "SCHEMA").map { |col|
              col['name']
            }, nil, nil, where)
        end
      end

      def primary_keys(table_name) # :nodoc:
        pks = table_structure(table_name).select { |f| f['pk'] > 0 }
        pks.sort_by { |f| f['pk'] }.map { |f| f['name'] }
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

      def foreign_keys(table_name)
        col_fk_names = {}
        table_structure(table_name).each do |col|
          col.fetch('foreign_keys', []).each do |fk|
            if fk.has_key?('name')
              col_fk_names[[col['name'], fk['to_table'], fk['target_column']]] = fk['name']
            end
          end
        end

        exec_query("PRAGMA foreign_key_list(#{quote_table_name(table_name)})", 'SCHEMA').map do |row|
          pkey = row['to']
          if pkey.nil?
            pkeys = primary_keys(row['table'])
            if pkeys.length == 1
              pkey = pkeys.first
            else
              # FIXME ForeignKeyDefinition can only refer to a single target column, so
              # for now we'll have to just ignore any multi-column targets.
              next nil
            end
          end

          ForeignKeyDefinition.new(table_name.to_s, row['table'], {
            name: col_fk_names[[row['from'], row['table'], row['to']]],
            column: row['from'],
            primary_key: pkey,
            on_delete: extract_foreign_key_action(row['on_delete']),
            on_update: extract_foreign_key_action(row['on_update'])
          })
        end.compact
      end

      def add_foreign_key(from_table, to_table, options = {}) #:nodoc:
        options = foreign_key_options(from_table, to_table, options)
        alter_table(from_table) do |definition|
          definition.foreign_key(to_table, options)
        end
      end

      def remove_foreign_key(from_table, options_or_to_table = {})
        foreign_key_for!(from_table, options_or_to_table)
        alter_table(from_table) do |definition|
          definition.remove_foreign_key(options_or_to_table)
        end
      end

      protected

        def alter_table(table_name, options = {}) #:nodoc:
          altered_table_name = "a#{table_name}"
          caller = lambda {|definition| yield definition if block_given?}

          transaction do
            move_table(table_name, altered_table_name, options)
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
                :limit => column.limit, :default => column.default,
                :precision => column.precision, :scale => column.scale,
                :null => column.null, collation: column.collation)
            end
            foreign_keys(from).each do |fk|
              @definition.foreign_key fk.to_table, fk.options
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
          quoted_columns = columns.map { |col| quote_column_name(col) } * ','
          quoted_from_columns = from_columns_to_copy.map { |col| quote_column_name(col) } * ','

          exec_query("INSERT INTO #{quote_table_name(to)} (#{quoted_columns})
                     SELECT #{quoted_from_columns} FROM #{quote_table_name(from)}")
        end

        def sqlite_version
          @sqlite_version ||= SQLite3Adapter::Version.new(select_value('select sqlite_version(*)'))
        end

        def translate_exception(exception, message)
          if exception.is_a? ::SQLite3::ConstraintException
            case exception.message
            # SQLite 3.8.2 returns a newly formatted error message:
            #   UNIQUE constraint failed: *table_name*.*column_name*
            # Older versions of SQLite return:
            #   column *column_name* is not unique
            when /column(s)? .* (is|are) not unique/, /^UNIQUE constraint failed: .*/i
              RecordNotUnique.new(message)
            when /^FOREIGN KEY constraint failed/i
              InvalidForeignKey.new(message)
            else
              super
            end
          else
            super
          end
        end

      private
        # Quoting styles documented at http://www.sqlite.org/lang_keywords.html
        # SQLite uses the repeated-quote style of escaping, e.g. "foo""" == 'foo"'
        SCHEMA_TOKEN_REGEX = /
            '  (?: [^']  | '' )* '  # Single-quoted string
          | "  (?: [^"]  | "" )* "  # Double-quoted string
          | `  (?: [^`]  | `` )* `  # Backtick-quoted string
          | \[     [^\]]       * \] # Bracket-bounded string
          | \w+                     # Raw unquoted literal
          | [(),]                   # Symbols
        /x.freeze

        def dequote_token(token)
          return "" if token.blank?
          quote_char = token[0]
          if ["'", '"', '[', '`'].include?(quote_char)
            token = token[1..-2] # Remove wrappnig quote characters
            if quote_char != '[' # The bracket syntax doesn't allow escapes
              token = token.gsub("#{quote_char}#{quote_char}", quote_char)
            end
          end
          token
        end

        def table_structure(table_name)
          structure = exec_query("PRAGMA table_info(#{quote_table_name(table_name)})", 'SCHEMA')
          raise(ActiveRecord::StatementInvalid, "Could not find table '#{table_name}'") if structure.empty?

          sql = "SELECT sql FROM sqlite_master WHERE type='table' and name=#{ quote(table_name) }"
          result = exec_query(sql, 'SCHEMA').first
          unless result
            return structure
          end

          table_tokens = result["sql"].scan(SCHEMA_TOKEN_REGEX)
          if table_tokens[-2..-1].map{|t| t.upcase} == ["WITHOUT", "ROWID"]
            table_tokens = table_tokens[0..-3] # Remove 'WITHOUT ROWID' from the end
          end

          if table_tokens[0..1].map{|t| t.upcase} != ["CREATE", "TABLE"]
            raise ActiveRecord::StatementInvalid, "Can't find CREATE TABLE schema: #{result["sql"]}"
          end
          table_tokens = table_tokens[3..-1] # Skip past 'CREATE TABLE tablename'

          if table_tokens.first != "(" or table_tokens.last != ")"
            raise ActiveRecord::StatementInvalid, "Incomplete CREATE TABLE schema: #{result["sql"]}"
          end

          cur_column = nil
          cur_tokens = []
          paren_depth = 0
          table_tokens.each do |token|
            if token == "("
              paren_depth += 1
              if paren_depth > 1
                cur_tokens << token
              end
            elsif token == "," or token == ")"
              if paren_depth == 1
                # This ")" or "," is a divider between two groups of tokens, so let's
                # parse the tokens we've accumulated so far
                column_info = parse_constraint_tokens(cur_column, cur_tokens)
                column_info.each do |col_name, info|
                  affected = structure.find { |col| col['name'] == col_name }
                  unless affected.nil?
                    if info.has_key?('collation')
                      affected['collation'] = info['collation']
                    end
                    if info.has_key?('foreign_keys')
                      (affected['foreign_keys'] ||= []).concat(info['foreign_keys'])
                    end
                  end
                end

                cur_column = nil
                cur_tokens = []
              else
                # This ")" or "," is within a group of tokens
                cur_tokens << token
              end

              if token == ")"
                paren_depth -= 1
              end
            elsif cur_column.nil?
              # See https://www.sqlite.org/syntax/table-constraint.html
              if ["CONSTRAINT", "PRIMARY", "UNIQUE", "CHECK", "FOREIGN"].include?(token.upcase)
                cur_tokens << token
                cur_column = :table_constraint
              else
                cur_column = dequote_token(token)
              end
            else
              cur_tokens << token
            end
          end

          structure
        end

        def extract_foreign_key_action(string)
          case string
          when 'NO ACTION' then nil
          when 'RESTRICT' then :restrict
          when 'SET NULL' then :nullify
          when 'CASCADE' then :cascade
          when 'SET DEFAULT' then nil # SchemaStatements::add_foreign_key doesn't support it
          end
        end

        # See https://www.sqlite.org/syntax/table-constraint.html
        # and https://www.sqlite.org/syntax/column-constraint.html
        # and https://www.sqlite.org/syntax/foreign-key-clause.html
        def parse_constraint_tokens(column_context, tokens)
          info = Hash.new { |h,k| h[k] = {} }

          constraint_name = nil

          while tokens.length > 0
            t = tokens.shift

            if t.upcase == "CONSTRAINT"
              # SQLite3 allows any constraint to have an optional name
              constraint_name = dequote_token(tokens.shift)
            elsif t.upcase == "COLLATE"
              info[column_context]['collation'] = dequote_token(tokens.shift)
              constraint_name = nil
            elsif t.upcase == "FOREIGN" and tokens.fourth == ")"
              # This 'FOREIGN KEY' specifies which source column is being referred to
              # in the upcoming 'REFERENCES' clause.
              # FIXME ForeignKeyDefinition can only represent a single source column, so for now
              # if we have more than one column in this FOREIGN KEY clause we'll just skip it.
              tokens.shift(2) # KEY (
              column_context = dequote_token(tokens.shift)
              tokens.shift # )
            elsif t.upcase == "REFERENCES"
              foreign_key_info = { 'to_table' => dequote_token(tokens.shift) }
              foreign_key_info['name'] = constraint_name unless constraint_name.nil?

              # FIXME ForeignKeyDefinition can only refer to a single target column, so
              # for now we'll have to just ignore any multi-column targets.
              if tokens.first == "(" and tokens.third == ")"
                tokens.shift # (
                foreign_key_info['target_column'] = dequote_token(tokens.shift)
                tokens.shift # )
              end

              (info[column_context]['foreign_keys'] ||= []).push foreign_key_info
              constraint_name = nil
            end
          end

          info
        end
    end
  end
end
