# frozen_string_literal: true

require "active_record/connection_adapters/abstract_adapter"
require "active_record/connection_adapters/statement_pool"
require "active_record/connection_adapters/sqlite3/column"
require "active_record/connection_adapters/sqlite3/explain_pretty_printer"
require "active_record/connection_adapters/sqlite3/quoting"
require "active_record/connection_adapters/sqlite3/database_statements"
require "active_record/connection_adapters/sqlite3/schema_creation"
require "active_record/connection_adapters/sqlite3/schema_definitions"
require "active_record/connection_adapters/sqlite3/schema_dumper"
require "active_record/connection_adapters/sqlite3/schema_statements"

gem "sqlite3", ">= 2.1"
require "sqlite3"

# Suppress the warning that SQLite3 issues when open writable connections are carried across fork()
SQLite3::ForkSafety.suppress_warnings!

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    # = Active Record SQLite3 Adapter
    #
    # The SQLite3 adapter works with the sqlite3-ruby drivers
    # (available as gem from https://rubygems.org/gems/sqlite3).
    #
    # ==== Options
    #
    # * <tt>:database</tt> - Path to the database file.
    class SQLite3Adapter < AbstractAdapter
      ADAPTER_NAME = "SQLite"

      class << self
        def new_client(config)
          ::SQLite3::Database.new(config[:database].to_s, config)
        rescue Errno::ENOENT => error
          if error.message.include?("No such file or directory")
            raise ActiveRecord::NoDatabaseError
          else
            raise
          end
        end

        def dbconsole(config, options = {})
          args = []

          args << "-#{options[:mode]}" if options[:mode]
          args << "-header" if options[:header]
          args << File.expand_path(config.database, Rails.respond_to?(:root) ? Rails.root : nil)

          find_cmd_and_exec(ActiveRecord.database_cli[:sqlite], *args)
        end
      end

      include SQLite3::Quoting
      include SQLite3::SchemaStatements
      include SQLite3::DatabaseStatements

      ##
      # :singleton-method:
      # Configure the SQLite3Adapter to be used in a strict strings mode.
      # This will disable double-quoted string literals, because otherwise typos can silently go unnoticed.
      # For example, it is possible to create an index for a non existing column.
      # If you wish to enable this mode you can add the following line to your application.rb file:
      #
      #   config.active_record.sqlite3_adapter_strict_strings_by_default = true
      class_attribute :strict_strings_by_default, default: false

      NATIVE_DATABASE_TYPES = {
        primary_key:  "integer PRIMARY KEY AUTOINCREMENT NOT NULL",
        string:       { name: "varchar" },
        text:         { name: "text" },
        integer:      { name: "integer" },
        float:        { name: "float" },
        decimal:      { name: "decimal" },
        datetime:     { name: "datetime" },
        time:         { name: "time" },
        date:         { name: "date" },
        binary:       { name: "blob" },
        boolean:      { name: "boolean" },
        json:         { name: "json" },
      }

      DEFAULT_PRAGMAS = {
        "foreign_keys"        => true,
        "journal_mode"        => :wal,
        "synchronous"         => :normal,
        "mmap_size"           => 134217728, # 128 megabytes
        "journal_size_limit"  => 67108864, # 64 megabytes
        "cache_size"          => 2000
      }

      class StatementPool < ConnectionAdapters::StatementPool # :nodoc:
        alias reset clear

        private
          def dealloc(stmt)
            stmt.close unless stmt.closed?
          end
      end

      def initialize(...)
        super

        @memory_database = false
        case @config[:database].to_s
        when ""
          raise ArgumentError, "No database file specified. Missing argument: database"
        when ":memory:"
          @memory_database = true
        when /\Afile:/
        else
          # Otherwise we have a path relative to Rails.root
          @config[:database] = File.expand_path(@config[:database], Rails.root) if defined?(Rails.root)
          dirname = File.dirname(@config[:database])
          unless File.directory?(dirname)
            begin
              FileUtils.mkdir_p(dirname)
            rescue SystemCallError
              raise ActiveRecord::NoDatabaseError.new(connection_pool: @pool)
            end
          end
        end

        @last_affected_rows = nil
        @previous_read_uncommitted = nil
        @config[:strict] = ConnectionAdapters::SQLite3Adapter.strict_strings_by_default unless @config.key?(:strict)
        @connection_parameters = @config.merge(
          database: @config[:database].to_s,
          results_as_hash: true,
          default_transaction_mode: :immediate,
        )
      end

      def database_exists?
        @config[:database] == ":memory:" || File.exist?(@config[:database].to_s)
      end

      def supports_ddl_transactions?
        true
      end

      def supports_savepoints?
        true
      end

      def supports_transaction_isolation?
        true
      end

      def supports_partial_index?
        true
      end

      def supports_expression_index?
        database_version >= "3.9.0"
      end

      def requires_reloading?
        true
      end

      def supports_foreign_keys?
        true
      end

      def supports_check_constraints?
        true
      end

      def supports_views?
        true
      end

      def supports_datetime_with_precision?
        true
      end

      def supports_json?
        true
      end

      def supports_common_table_expressions?
        database_version >= "3.8.3"
      end

      def supports_insert_returning?
        database_version >= "3.35.0"
      end

      def supports_insert_on_conflict?
        database_version >= "3.24.0"
      end
      alias supports_insert_on_duplicate_skip? supports_insert_on_conflict?
      alias supports_insert_on_duplicate_update? supports_insert_on_conflict?
      alias supports_insert_conflict_target? supports_insert_on_conflict?

      def supports_concurrent_connections?
        !@memory_database
      end

      def supports_virtual_columns?
        database_version >= "3.31.0"
      end

      def connected?
        !(@raw_connection.nil? || @raw_connection.closed?)
      end

      def active?
        if connected?
          verified!
          true
        end
      end

      alias :reset! :reconnect!

      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        super

        @raw_connection&.close rescue nil
        @raw_connection = nil
      end

      def supports_index_sort_order?
        true
      end

      def native_database_types # :nodoc:
        NATIVE_DATABASE_TYPES
      end

      # Returns the current database encoding format as a string, e.g. 'UTF-8'
      def encoding
        any_raw_connection.encoding.to_s
      end

      def supports_explain?
        true
      end

      def supports_lazy_transactions?
        true
      end

      def supports_deferrable_constraints?
        true
      end

      # REFERENTIAL INTEGRITY ====================================

      def disable_referential_integrity # :nodoc:
        old_foreign_keys = query_value("PRAGMA foreign_keys")
        old_defer_foreign_keys = query_value("PRAGMA defer_foreign_keys")

        begin
          execute("PRAGMA defer_foreign_keys = ON")
          execute("PRAGMA foreign_keys = OFF")
          yield
        ensure
          execute("PRAGMA defer_foreign_keys = #{old_defer_foreign_keys}")
          execute("PRAGMA foreign_keys = #{old_foreign_keys}")
        end
      end

      def check_all_foreign_keys_valid! # :nodoc:
        sql = "PRAGMA foreign_key_check"
        result = execute(sql)

        unless result.blank?
          tables = result.map { |row| row["table"] }
          raise ActiveRecord::StatementInvalid.new("Foreign key violations found: #{tables.join(", ")}", sql: sql, connection_pool: @pool)
        end
      end

      # SCHEMA STATEMENTS ========================================

      def primary_keys(table_name) # :nodoc:
        pks = table_structure(table_name).select { |f| f["pk"] > 0 }
        pks.sort_by { |f| f["pk"] }.map { |f| f["name"] }
      end

      def remove_index(table_name, column_name = nil, **options) # :nodoc:
        return if options[:if_exists] && !index_exists?(table_name, column_name, **options)

        index_name = index_name_for_remove(table_name, column_name, options)

        exec_query "DROP INDEX #{quote_column_name(index_name)}"
      end

      VIRTUAL_TABLE_REGEX = /USING\s+(\w+)\s*\((.+)\)/i

      # Returns a list of defined virtual tables
      def virtual_tables
        query = <<~SQL
          SELECT name, sql FROM sqlite_master WHERE sql LIKE 'CREATE VIRTUAL %';
        SQL

        exec_query(query, "SCHEMA").cast_values.each_with_object({}) do |row, memo|
          table_name, sql = row[0], row[1]
          _, module_name, arguments = sql.match(VIRTUAL_TABLE_REGEX).to_a
          memo[table_name] = [module_name, arguments]
        end.to_a
      end

      # Creates a virtual table
      #
      # Example:
      #   create_virtual_table :emails, :fts5, ['sender', 'title', 'body']
      def create_virtual_table(table_name, module_name, values)
        exec_query "CREATE VIRTUAL TABLE IF NOT EXISTS #{table_name} USING #{module_name} (#{values.join(", ")})"
      end

      # Drops a virtual table
      #
      # Although this command ignores +module_name+ and +values+,
      # it can be helpful to provide these in a migration's +change+ method so it can be reverted.
      # In that case, +module_name+, +values+ and +options+ will be used by #create_virtual_table.
      def drop_virtual_table(table_name, module_name, values, **options)
        drop_table(table_name)
      end

      # Renames a table.
      #
      # Example:
      #   rename_table('octopuses', 'octopi')
      def rename_table(table_name, new_name, **options)
        validate_table_length!(new_name) unless options[:_uses_legacy_table_name]
        schema_cache.clear_data_source_cache!(table_name.to_s)
        schema_cache.clear_data_source_cache!(new_name.to_s)
        exec_query "ALTER TABLE #{quote_table_name(table_name)} RENAME TO #{quote_table_name(new_name)}"
        rename_table_indexes(table_name, new_name, **options)
      end

      def add_column(table_name, column_name, type, **options) # :nodoc:
        type = type.to_sym
        if invalid_alter_table_type?(type, options)
          alter_table(table_name) do |definition|
            definition.column(column_name, type, **options)
          end
        else
          super
        end
      end

      def remove_column(table_name, column_name, type = nil, **options) # :nodoc:
        alter_table(table_name) do |definition|
          definition.remove_column column_name
          definition.foreign_keys.delete_if { |fk| fk.column == column_name.to_s }
        end
      end

      def remove_columns(table_name, *column_names, type: nil, **options) # :nodoc:
        alter_table(table_name) do |definition|
          column_names.each do |column_name|
            definition.remove_column column_name
          end
          column_names = column_names.map(&:to_s)
          definition.foreign_keys.delete_if { |fk| column_names.include?(fk.column) }
        end
      end

      def change_column_default(table_name, column_name, default_or_changes) # :nodoc:
        default = extract_new_default_value(default_or_changes)

        alter_table(table_name) do |definition|
          definition[column_name].default = default
        end
      end

      def change_column_null(table_name, column_name, null, default = nil) # :nodoc:
        validate_change_column_null_argument!(null)

        unless null || default.nil?
          internal_exec_query("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
        end
        alter_table(table_name) do |definition|
          definition[column_name].null = null
        end
      end

      def change_column(table_name, column_name, type, **options) # :nodoc:
        alter_table(table_name) do |definition|
          definition.change_column(column_name, type, **options)
        end
      end

      def rename_column(table_name, column_name, new_column_name) # :nodoc:
        column = column_for(table_name, column_name)
        alter_table(table_name, rename: { column.name => new_column_name.to_s })
        rename_column_indexes(table_name, column.name, new_column_name)
      end

      def add_timestamps(table_name, **options)
        options[:null] = false if options[:null].nil?

        if !options.key?(:precision)
          options[:precision] = 6
        end

        alter_table(table_name) do |definition|
          definition.column :created_at, :datetime, **options
          definition.column :updated_at, :datetime, **options
        end
      end

      def add_reference(table_name, ref_name, **options) # :nodoc:
        super(table_name, ref_name, type: :integer, **options)
      end
      alias :add_belongs_to :add_reference

      FK_REGEX = /.*FOREIGN KEY\s+\("([^"]+)"\)\s+REFERENCES\s+"(\w+)"\s+\("(\w+)"\)/
      DEFERRABLE_REGEX = /DEFERRABLE INITIALLY (\w+)/
      def foreign_keys(table_name)
        # SQLite returns 1 row for each column of composite foreign keys.
        fk_info = internal_exec_query("PRAGMA foreign_key_list(#{quote(table_name)})", "SCHEMA")
        # Deferred or immediate foreign keys can only be seen in the CREATE TABLE sql
        fk_defs = table_structure_sql(table_name)
                    .select do |column_string|
                      column_string.start_with?("CONSTRAINT") &&
                      column_string.include?("FOREIGN KEY")
                    end
                    .to_h do |fk_string|
                      _, from, table, to = fk_string.match(FK_REGEX).to_a
                      _, mode = fk_string.match(DEFERRABLE_REGEX).to_a
                      deferred = mode&.downcase&.to_sym || false
                      [[table, from, to], deferred]
                    end

        grouped_fk = fk_info.group_by { |row| row["id"] }.values.each { |group| group.sort_by! { |row| row["seq"] } }
        grouped_fk.map do |group|
          row = group.first
          options = {
            on_delete: extract_foreign_key_action(row["on_delete"]),
            on_update: extract_foreign_key_action(row["on_update"]),
            deferrable: fk_defs[[row["table"], row["from"], row["to"]]]
          }

          if group.one?
            options[:column] = row["from"]
            options[:primary_key] = row["to"]
          else
            options[:column] = group.map { |row| row["from"] }
            options[:primary_key] = group.map { |row| row["to"] }
          end
          ForeignKeyDefinition.new(table_name, row["table"], options)
        end
      end

      def build_insert_sql(insert) # :nodoc:
        sql = +"INSERT #{insert.into} #{insert.values_list}"

        if insert.skip_duplicates?
          sql << " ON CONFLICT #{insert.conflict_target} DO NOTHING"
        elsif insert.update_duplicates?
          sql << " ON CONFLICT #{insert.conflict_target} DO UPDATE SET "
          if insert.raw_update_sql?
            sql << insert.raw_update_sql
          else
            sql << insert.touch_model_timestamps_unless { |column| "#{column} IS excluded.#{column}" }
            sql << insert.updatable_columns.map { |column| "#{column}=excluded.#{column}" }.join(",")
          end
        end

        sql << " RETURNING #{insert.returning}" if insert.returning
        sql
      end

      def shared_cache? # :nodoc:
        @config.fetch(:flags, 0).anybits?(::SQLite3::Constants::Open::SHAREDCACHE)
      end

      def get_database_version # :nodoc:
        SQLite3Adapter::Version.new(query_value("SELECT sqlite_version(*)", "SCHEMA"))
      end

      def check_version # :nodoc:
        if database_version < "3.8.0"
          raise "Your version of SQLite (#{database_version}) is too old. Active Record supports SQLite >= 3.8."
        end
      end

      class SQLite3Integer < Type::Integer # :nodoc:
        private
          def _limit
            # INTEGER storage class can be stored 8 bytes value.
            # See https://www.sqlite.org/datatype3.html#storage_classes_and_datatypes
            limit || 8
          end
      end

      ActiveRecord::Type.register(:integer, SQLite3Integer, adapter: :sqlite3)

      class << self
        private
          def initialize_type_map(m)
            super
            register_class_with_limit m, %r(int)i, SQLite3Integer
          end
      end

      TYPE_MAP = Type::TypeMap.new.tap { |m| initialize_type_map(m) }
      EXTENDED_TYPE_MAPS = Concurrent::Map.new

      private
        # See https://www.sqlite.org/limits.html,
        # the default value is 999 when not configured.
        def bind_params_length
          999
        end

        def table_structure(table_name)
          structure = table_info(table_name)
          raise ActiveRecord::StatementInvalid.new("Could not find table '#{table_name}'", connection_pool: @pool) if structure.empty?
          table_structure_with_collation(table_name, structure)
        end
        alias column_definitions table_structure

        def extract_value_from_default(default)
          case default
          when /^null$/i
            nil
          # Quoted types
          when /^'([^|]*)'$/m
            $1.gsub("''", "'")
          # Quoted types
          when /^"([^|]*)"$/m
            $1.gsub('""', '"')
          # Numeric types
          when /\A-?\d+(\.\d*)?\z/
            $&
          # Binary columns
          when /x'(.*)'/
            [ $1 ].pack("H*")
          else
            # Anything else is blank or some function
            # and we can't know the value of that, so return nil.
            nil
          end
        end

        def extract_default_function(default_value, default)
          default if has_default_function?(default_value, default)
        end

        def has_default_function?(default_value, default)
          !default_value && %r{\w+\(.*\)|CURRENT_TIME|CURRENT_DATE|CURRENT_TIMESTAMP|\|\|}.match?(default)
        end

        # See: https://www.sqlite.org/lang_altertable.html
        # SQLite has an additional restriction on the ALTER TABLE statement
        def invalid_alter_table_type?(type, options)
          type == :primary_key || options[:primary_key] ||
            options[:null] == false && options[:default].nil? ||
            (type == :virtual && options[:stored])
        end

        def alter_table(
          table_name,
          foreign_keys = foreign_keys(table_name),
          check_constraints = check_constraints(table_name),
          **options
        )
          altered_table_name = "a#{table_name}"

          caller = lambda do |definition|
            rename = options[:rename] || {}
            foreign_keys.each do |fk|
              if column = rename[fk.options[:column]]
                fk.options[:column] = column
              end
              to_table = strip_table_name_prefix_and_suffix(fk.to_table)
              definition.foreign_key(to_table, **fk.options)
            end

            check_constraints.each do |chk|
              definition.check_constraint(chk.expression, **chk.options)
            end

            yield definition if block_given?
          end

          transaction do
            disable_referential_integrity do
              move_table(table_name, altered_table_name, options.merge(temporary: true))
              move_table(altered_table_name, table_name, &caller)
            end
          end
        end

        def move_table(from, to, options = {}, &block)
          copy_table(from, to, options, &block)
          drop_table(from)
        end

        def copy_table(from, to, options = {})
          from_primary_key = primary_key(from)
          options[:id] = false
          create_table(to, **options) do |definition|
            @definition = definition
            if from_primary_key.is_a?(Array)
              @definition.primary_keys from_primary_key
            end

            columns(from).each do |column|
              column_name = options[:rename] ?
                (options[:rename][column.name] ||
                 options[:rename][column.name.to_sym] ||
                 column.name) : column.name

              column_options = {
                limit: column.limit,
                precision: column.precision,
                scale: column.scale,
                null: column.null,
                collation: column.collation,
                primary_key: column_name == from_primary_key
              }

              if column.virtual?
                column_options[:as] = column.default_function
                column_options[:stored] = column.virtual_stored?
                column_options[:type] = column.type
              elsif column.has_default?
                type = lookup_cast_type_from_column(column)
                default = type.deserialize(column.default)
                default = -> { column.default_function } if default.nil?

                unless column.auto_increment?
                  column_options[:default] = default
                end
              end

              column_type = column.virtual? ? :virtual : (column.bigint? ? :bigint : column.type)
              @definition.column(column_name, column_type, **column_options)
            end

            yield @definition if block_given?
          end
          copy_table_indexes(from, to, options[:rename] || {})

          columns_to_copy = @definition.columns.reject { |col| col.options.key?(:as) }.map(&:name)
          copy_table_contents(from, to,
            columns_to_copy,
            options[:rename] || {})
        end

        def copy_table_indexes(from, to, rename = {})
          indexes(from).each do |index|
            name = index.name
            if to == "a#{from}"
              name = "t#{name}"
            elsif from == "a#{to}"
              name = name[1..-1]
            end

            columns = index.columns
            if columns.is_a?(Array)
              to_column_names = columns(to).map(&:name)
              columns = columns.map { |c| rename[c] || c }.select do |column|
                to_column_names.include?(column)
              end
            end

            unless columns.empty?
              # index name can't be the same
              options = { name: name.gsub(/(^|_)(#{from})_/, "\\1#{to}_"), internal: true }
              options[:unique] = true if index.unique
              options[:where] = index.where if index.where
              options[:order] = index.orders if index.orders
              add_index(to, columns, **options)
            end
          end
        end

        def copy_table_contents(from, to, columns, rename = {})
          column_mappings = Hash[columns.map { |name| [name, name] }]
          rename.each { |a| column_mappings[a.last] = a.first }
          from_columns = columns(from).collect(&:name)
          columns = columns.find_all { |col| from_columns.include?(column_mappings[col]) }
          from_columns_to_copy = columns.map { |col| column_mappings[col] }
          quoted_columns = columns.map { |col| quote_column_name(col) } * ","
          quoted_from_columns = from_columns_to_copy.map { |col| quote_column_name(col) } * ","

          internal_exec_query("INSERT INTO #{quote_table_name(to)} (#{quoted_columns})
                     SELECT #{quoted_from_columns} FROM #{quote_table_name(from)}")
        end

        def translate_exception(exception, message:, sql:, binds:)
          # SQLite 3.8.2 returns a newly formatted error message:
          #   UNIQUE constraint failed: *table_name*.*column_name*
          # Older versions of SQLite return:
          #   column *column_name* is not unique
          if exception.message.match?(/(column(s)? .* (is|are) not unique|UNIQUE constraint failed: .*)/i)
            RecordNotUnique.new(message, sql: sql, binds: binds, connection_pool: @pool)
          elsif exception.message.match?(/(.* may not be NULL|NOT NULL constraint failed: .*)/i)
            NotNullViolation.new(message, sql: sql, binds: binds, connection_pool: @pool)
          elsif exception.message.match?(/FOREIGN KEY constraint failed/i)
            InvalidForeignKey.new(message, sql: sql, binds: binds, connection_pool: @pool)
          elsif exception.message.match?(/called on a closed database/i)
            ConnectionNotEstablished.new(exception, connection_pool: @pool)
          elsif exception.is_a?(::SQLite3::BusyException)
            StatementTimeout.new(message, sql: sql, binds: binds, connection_pool: @pool)
          else
            super
          end
        end

        COLLATE_REGEX = /.*"(\w+)".*collate\s+"(\w+)".*/i
        PRIMARY_KEY_AUTOINCREMENT_REGEX = /.*"(\w+)".+PRIMARY KEY AUTOINCREMENT/i
        GENERATED_ALWAYS_AS_REGEX = /.*"(\w+)".+GENERATED ALWAYS AS \((.+)\) (?:STORED|VIRTUAL)/i

        def table_structure_with_collation(table_name, basic_structure)
          collation_hash = {}
          auto_increments = {}
          generated_columns = {}

          column_strings = table_structure_sql(table_name, basic_structure.map { |column| column["name"] })

          if column_strings.any?
            column_strings.each do |column_string|
              # This regex will match the column name and collation type and will save
              # the value in $1 and $2 respectively.
              collation_hash[$1] = $2 if COLLATE_REGEX =~ column_string
              auto_increments[$1] = true if PRIMARY_KEY_AUTOINCREMENT_REGEX =~ column_string
              generated_columns[$1] = $2 if GENERATED_ALWAYS_AS_REGEX =~ column_string
            end

            basic_structure.map do |column|
              column_name = column["name"]

              if collation_hash.has_key? column_name
                column["collation"] = collation_hash[column_name]
              end

              if auto_increments.has_key?(column_name)
                column["auto_increment"] = true
              end

              if generated_columns.has_key?(column_name)
                column["dflt_value"] = generated_columns[column_name]
              end

              column
            end
          else
            basic_structure.to_a
          end
        end

        UNQUOTED_OPEN_PARENS_REGEX = /\((?![^'"]*['"][^'"]*$)/
        FINAL_CLOSE_PARENS_REGEX = /\);*\z/

        def table_structure_sql(table_name, column_names = nil)
          unless column_names
            column_info = table_info(table_name)
            column_names = column_info.map { |column| column["name"] }
          end

          sql = <<~SQL
            SELECT sql FROM
              (SELECT * FROM sqlite_master UNION ALL
               SELECT * FROM sqlite_temp_master)
            WHERE type = 'table' AND name = #{quote(table_name)}
          SQL

          # Result will have following sample string
          # CREATE TABLE "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          #                       "password_digest" varchar COLLATE "NOCASE",
          #                       "o_id" integer,
          #                       CONSTRAINT "fk_rails_78146ddd2e" FOREIGN KEY ("o_id") REFERENCES "os" ("id"));
          result = query_value(sql, "SCHEMA")

          return [] unless result

          # Splitting with left parentheses and discarding the first part will return all
          # columns separated with comma(,).
          result.partition(UNQUOTED_OPEN_PARENS_REGEX)
                .last
                .sub(FINAL_CLOSE_PARENS_REGEX, "")
                # column definitions can have a comma in them, so split on commas followed
                # by a space and a column name in quotes or followed by the keyword CONSTRAINT
                .split(/,(?=\s(?:CONSTRAINT|"(?:#{Regexp.union(column_names).source})"))/i)
                .map(&:strip)
        end

        def table_info(table_name)
          if supports_virtual_columns?
            internal_exec_query("PRAGMA table_xinfo(#{quote_table_name(table_name)})", "SCHEMA")
          else
            internal_exec_query("PRAGMA table_info(#{quote_table_name(table_name)})", "SCHEMA")
          end
        end

        def arel_visitor
          Arel::Visitors::SQLite.new(self)
        end

        def build_statement_pool
          StatementPool.new(self.class.type_cast_config_to_integer(@config[:statement_limit]))
        end

        def connect
          @raw_connection = self.class.new_client(@connection_parameters)
        rescue ConnectionNotEstablished => ex
          raise ex.set_pool(@pool)
        end

        def reconnect
          if active?
            @raw_connection.rollback rescue nil
          else
            connect
          end
        end

        def configure_connection
          if @config[:timeout] && @config[:retries]
            raise ArgumentError, "Cannot specify both timeout and retries arguments"
          elsif @config[:timeout]
            timeout = self.class.type_cast_config_to_integer(@config[:timeout])
            raise TypeError, "timeout must be integer, not #{timeout}" unless timeout.is_a?(Integer)
            @raw_connection.busy_handler_timeout = timeout
          elsif @config[:retries]
            ActiveRecord.deprecator.warn(<<~MSG)
              The retries option is deprecated and will be removed in Rails 8.1. Use timeout instead.
            MSG
            retries = self.class.type_cast_config_to_integer(@config[:retries])
            raw_connection.busy_handler { |count| count <= retries }
          end

          super

          pragmas = @config.fetch(:pragmas, {}).stringify_keys
          DEFAULT_PRAGMAS.merge(pragmas).each do |pragma, value|
            if ::SQLite3::Pragmas.method_defined?("#{pragma}=")
              @raw_connection.public_send("#{pragma}=", value)
            else
              warn "Unknown SQLite pragma: #{pragma}"
            end
          end
        end
    end
    ActiveSupport.run_load_hooks(:active_record_sqlite3adapter, SQLite3Adapter)
  end
end
