require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/statement_pool'
require 'active_record/connection_adapters/mysql/column'
require 'active_record/connection_adapters/mysql/explain_pretty_printer'
require 'active_record/connection_adapters/mysql/quoting'
require 'active_record/connection_adapters/mysql/schema_creation'
require 'active_record/connection_adapters/mysql/schema_definitions'
require 'active_record/connection_adapters/mysql/schema_dumper'
require 'active_record/connection_adapters/mysql/type_metadata'

require 'active_support/core_ext/string/strip'
require 'active_support/core_ext/regexp'

module ActiveRecord
  module ConnectionAdapters
    class AbstractMysqlAdapter < AbstractAdapter
      include MySQL::Quoting
      include MySQL::ColumnDumper

      def update_table_definition(table_name, base) # :nodoc:
        MySQL::Table.new(table_name, base)
      end

      def schema_creation # :nodoc:
        MySQL::SchemaCreation.new(self)
      end

      def arel_visitor # :nodoc:
        Arel::Visitors::MySQL.new(self)
      end

      ##
      # :singleton-method:
      # By default, the Mysql2Adapter will consider all columns of type <tt>tinyint(1)</tt>
      # as boolean. If you wish to disable this emulation you can add the following line
      # to your application.rb file:
      #
      #   ActiveRecord::ConnectionAdapters::Mysql2Adapter.emulate_booleans = false
      class_attribute :emulate_booleans
      self.emulate_booleans = true

      NATIVE_DATABASE_TYPES = {
        primary_key: "int auto_increment PRIMARY KEY",
        string:      { name: "varchar", limit: 255 },
        text:        { name: "text", limit: 65535 },
        integer:     { name: "int", limit: 4 },
        float:       { name: "float" },
        decimal:     { name: "decimal" },
        datetime:    { name: "datetime" },
        time:        { name: "time" },
        date:        { name: "date" },
        binary:      { name: "blob", limit: 65535 },
        boolean:     { name: "tinyint", limit: 1 },
        json:        { name: "json" },
      }

      INDEX_TYPES  = [:fulltext, :spatial]
      INDEX_USINGS = [:btree, :hash]

      class StatementPool < ConnectionAdapters::StatementPool
        private def dealloc(stmt)
          stmt[:stmt].close
        end
      end

      def initialize(connection, logger, connection_options, config)
        super(connection, logger, config)

        @statements = StatementPool.new(self.class.type_cast_config_to_integer(config[:statement_limit]))

        if version < '5.0.0'
          raise "Your version of MySQL (#{full_version.match(/^\d+\.\d+\.\d+/)[0]}) is too old. Active Record supports MySQL >= 5.0."
        end
      end

      CHARSETS_OF_4BYTES_MAXLEN = ['utf8mb4', 'utf16', 'utf16le', 'utf32']

      def internal_string_options_for_primary_key # :nodoc:
        super.tap { |options|
          options[:collation] = collation.sub(/\A[^_]+/, 'utf8') if CHARSETS_OF_4BYTES_MAXLEN.include?(charset)
        }
      end

      def version #:nodoc:
        @version ||= Version.new(full_version.match(/^\d+\.\d+\.\d+/)[0])
      end

      def mariadb? # :nodoc:
        /mariadb/i.match?(full_version)
      end

      # Returns true, since this connection adapter supports migrations.
      def supports_migrations?
        true
      end

      def supports_primary_key?
        true
      end

      def supports_bulk_alter? #:nodoc:
        true
      end

      # Returns true, since this connection adapter supports prepared statement
      # caching.
      def supports_statement_cache?
        true
      end

      # Technically MySQL allows to create indexes with the sort order syntax
      # but at the moment (5.5) it doesn't yet implement them
      def supports_index_sort_order?
        true
      end

      def supports_transaction_isolation?
        true
      end

      def supports_explain?
        true
      end

      def supports_indexes_in_create?
        true
      end

      def supports_foreign_keys?
        true
      end

      def supports_views?
        true
      end

      def supports_datetime_with_precision?
        if mariadb?
          version >= '5.3.0'
        else
          version >= '5.6.4'
        end
      end

      def supports_advisory_locks?
        true
      end

      def get_advisory_lock(lock_name, timeout = 0) # :nodoc:
        select_value("SELECT GET_LOCK(#{quote(lock_name)}, #{timeout})") == 1
      end

      def release_advisory_lock(lock_name) # :nodoc:
        select_value("SELECT RELEASE_LOCK(#{quote(lock_name)})") == 1
      end

      def native_database_types
        NATIVE_DATABASE_TYPES
      end

      def index_algorithms
        { default: 'ALGORITHM = DEFAULT', copy: 'ALGORITHM = COPY', inplace: 'ALGORITHM = INPLACE' }
      end

      # HELPER METHODS ===========================================

      # The two drivers have slightly different ways of yielding hashes of results, so
      # this method must be implemented to provide a uniform interface.
      def each_hash(result) # :nodoc:
        raise NotImplementedError
      end

      def new_column(*args) #:nodoc:
        MySQL::Column.new(*args)
      end

      # Must return the MySQL error number from the exception, if the exception has an
      # error number.
      def error_number(exception) # :nodoc:
        raise NotImplementedError
      end

      # REFERENTIAL INTEGRITY ====================================

      def disable_referential_integrity #:nodoc:
        old = select_value("SELECT @@FOREIGN_KEY_CHECKS")

        begin
          update("SET FOREIGN_KEY_CHECKS = 0")
          yield
        ensure
          update("SET FOREIGN_KEY_CHECKS = #{old}")
        end
      end

      # CONNECTION MANAGEMENT ====================================

      # Clears the prepared statements cache.
      def clear_cache!
        reload_type_map
        @statements.clear
      end

      #--
      # DATABASE STATEMENTS ======================================
      #++

      def explain(arel, binds = [])
        sql     = "EXPLAIN #{to_sql(arel, binds)}"
        start   = Time.now
        result  = exec_query(sql, 'EXPLAIN', binds)
        elapsed = Time.now - start

        MySQL::ExplainPrettyPrinter.new.pp(result, elapsed)
      end

      # Executes the SQL statement in the context of this connection.
      def execute(sql, name = nil)
        log(sql, name) { @connection.query(sql) }
      end

      # Mysql2Adapter doesn't have to free a result after using it, but we use this method
      # to write stuff in an abstract way without concerning ourselves about whether it
      # needs to be explicitly freed or not.
      def execute_and_free(sql, name = nil) # :nodoc:
        yield execute(sql, name)
      end

      def begin_db_transaction
        execute "BEGIN"
      end

      def begin_isolated_db_transaction(isolation)
        execute "SET TRANSACTION ISOLATION LEVEL #{transaction_isolation_levels.fetch(isolation)}"
        begin_db_transaction
      end

      def commit_db_transaction #:nodoc:
        execute "COMMIT"
      end

      def exec_rollback_db_transaction #:nodoc:
        execute "ROLLBACK"
      end

      # In the simple case, MySQL allows us to place JOINs directly into the UPDATE
      # query. However, this does not allow for LIMIT, OFFSET and ORDER. To support
      # these, we must use a subquery.
      def join_to_update(update, select, key) # :nodoc:
        if select.limit || select.offset || select.orders.any?
          super
        else
          update.table select.source
          update.wheres = select.constraints
        end
      end

      def empty_insert_statement_value
        "VALUES ()"
      end

      # SCHEMA STATEMENTS ========================================

      # Drops the database specified on the +name+ attribute
      # and creates it again using the provided +options+.
      def recreate_database(name, options = {})
        drop_database(name)
        sql = create_database(name, options)
        reconnect!
        sql
      end

      # Create a new MySQL database with optional <tt>:charset</tt> and <tt>:collation</tt>.
      # Charset defaults to utf8.
      #
      # Example:
      #   create_database 'charset_test', charset: 'latin1', collation: 'latin1_bin'
      #   create_database 'matt_development'
      #   create_database 'matt_development', charset: :big5
      def create_database(name, options = {})
        if options[:collation]
          execute "CREATE DATABASE #{quote_table_name(name)} DEFAULT CHARACTER SET #{quote_table_name(options[:charset] || 'utf8')} COLLATE #{quote_table_name(options[:collation])}"
        else
          execute "CREATE DATABASE #{quote_table_name(name)} DEFAULT CHARACTER SET #{quote_table_name(options[:charset] || 'utf8')}"
        end
      end

      # Drops a MySQL database.
      #
      # Example:
      #   drop_database('sebastian_development')
      def drop_database(name) #:nodoc:
        execute "DROP DATABASE IF EXISTS #{quote_table_name(name)}"
      end

      def current_database
        select_value 'SELECT DATABASE() as db'
      end

      # Returns the database character set.
      def charset
        show_variable 'character_set_database'
      end

      # Returns the database collation strategy.
      def collation
        show_variable 'collation_database'
      end

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
        sql = "SELECT table_name FROM information_schema.tables "
        sql << "WHERE table_schema = #{quote(@config[:database])}"

        select_values(sql, 'SCHEMA')
      end

      def truncate(table_name, name = nil)
        execute "TRUNCATE TABLE #{quote_table_name(table_name)}", name
      end

      def table_exists?(table_name)
        # Update lib/active_record/internal_metadata.rb when this gets removed
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          #table_exists? currently checks both tables and views.
          This behavior is deprecated and will be changed with Rails 5.1 to only check tables.
          Use #data_source_exists? instead.
        MSG

        data_source_exists?(table_name)
      end

      def data_source_exists?(table_name)
        return false unless table_name.present?

        schema, name = extract_schema_qualified_name(table_name)

        sql = "SELECT table_name FROM information_schema.tables "
        sql << "WHERE table_schema = #{quote(schema)} AND table_name = #{quote(name)}"

        select_values(sql, 'SCHEMA').any?
      end

      def views # :nodoc:
        select_values("SHOW FULL TABLES WHERE table_type = 'VIEW'", 'SCHEMA')
      end

      def view_exists?(view_name) # :nodoc:
        return false unless view_name.present?

        schema, name = extract_schema_qualified_name(view_name)

        sql = "SELECT table_name FROM information_schema.tables WHERE table_type = 'VIEW'"
        sql << " AND table_schema = #{quote(schema)} AND table_name = #{quote(name)}"

        select_values(sql, 'SCHEMA').any?
      end

      # Returns an array of indexes for the given table.
      def indexes(table_name, name = nil) #:nodoc:
        indexes = []
        current_index = nil
        execute_and_free("SHOW KEYS FROM #{quote_table_name(table_name)}", 'SCHEMA') do |result|
          each_hash(result) do |row|
            if current_index != row[:Key_name]
              next if row[:Key_name] == 'PRIMARY' # skip the primary key
              current_index = row[:Key_name]

              mysql_index_type = row[:Index_type].downcase.to_sym
              index_type  = INDEX_TYPES.include?(mysql_index_type)  ? mysql_index_type : nil
              index_using = INDEX_USINGS.include?(mysql_index_type) ? mysql_index_type : nil
              indexes << IndexDefinition.new(row[:Table], row[:Key_name], row[:Non_unique].to_i == 0, [], [], nil, nil, index_type, index_using, row[:Index_comment].presence)
            end

            indexes.last.columns << row[:Column_name]
            indexes.last.lengths << row[:Sub_part]
          end
        end

        indexes
      end

      # Returns an array of +Column+ objects for the table specified by +table_name+.
      def columns(table_name) # :nodoc:
        table_name = table_name.to_s
        column_definitions(table_name).map do |field|
          type_metadata = fetch_type_metadata(field[:Type], field[:Extra])
          if type_metadata.type == :datetime && field[:Default] == "CURRENT_TIMESTAMP"
            default, default_function = nil, field[:Default]
          else
            default, default_function = field[:Default], nil
          end
          new_column(field[:Field], default, type_metadata, field[:Null] == "YES", table_name, default_function, field[:Collation], comment: field[:Comment].presence)
        end
      end

      def table_comment(table_name) # :nodoc:
        select_value(<<-SQL.strip_heredoc, 'SCHEMA')
          SELECT table_comment
          FROM information_schema.tables
          WHERE table_schema=#{quote(current_database)}
            AND table_name=#{quote(table_name)}
        SQL
      end

      def create_table(table_name, **options) #:nodoc:
        super(table_name, options: 'ENGINE=InnoDB', **options)
      end

      def bulk_change_table(table_name, operations) #:nodoc:
        sqls = operations.flat_map do |command, args|
          table, arguments = args.shift, args
          method = :"#{command}_sql"

          if respond_to?(method, true)
            send(method, table, *arguments)
          else
            raise "Unknown method called : #{method}(#{arguments.inspect})"
          end
        end.join(", ")

        execute("ALTER TABLE #{quote_table_name(table_name)} #{sqls}")
      end

      # Renames a table.
      #
      # Example:
      #   rename_table('octopuses', 'octopi')
      def rename_table(table_name, new_name)
        execute "RENAME TABLE #{quote_table_name(table_name)} TO #{quote_table_name(new_name)}"
        rename_table_indexes(table_name, new_name)
      end

      # Drops a table from the database.
      #
      # [<tt>:force</tt>]
      #   Set to +:cascade+ to drop dependent objects as well.
      #   Defaults to false.
      # [<tt>:if_exists</tt>]
      #   Set to +true+ to only drop the table if it exists.
      #   Defaults to false.
      # [<tt>:temporary</tt>]
      #   Set to +true+ to drop temporary table.
      #   Defaults to false.
      #
      # Although this command ignores most +options+ and the block if one is given,
      # it can be helpful to provide these in a migration's +change+ method so it can be reverted.
      # In that case, +options+ and the block will be used by create_table.
      def drop_table(table_name, options = {})
        execute "DROP#{' TEMPORARY' if options[:temporary]} TABLE#{' IF EXISTS' if options[:if_exists]} #{quote_table_name(table_name)}#{' CASCADE' if options[:force] == :cascade}"
      end

      def rename_index(table_name, old_name, new_name)
        if supports_rename_index?
          validate_index_length!(table_name, new_name)

          execute "ALTER TABLE #{quote_table_name(table_name)} RENAME INDEX #{quote_table_name(old_name)} TO #{quote_table_name(new_name)}"
        else
          super
        end
      end

      def change_column_default(table_name, column_name, default_or_changes) #:nodoc:
        default = extract_new_default_value(default_or_changes)
        column = column_for(table_name, column_name)
        change_column table_name, column_name, column.sql_type, :default => default
      end

      def change_column_null(table_name, column_name, null, default = nil) #:nodoc:
        column = column_for(table_name, column_name)

        unless null || default.nil?
          execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
        end

        change_column table_name, column_name, column.sql_type, :null => null
      end

      def change_column(table_name, column_name, type, options = {}) #:nodoc:
        execute("ALTER TABLE #{quote_table_name(table_name)} #{change_column_sql(table_name, column_name, type, options)}")
      end

      def rename_column(table_name, column_name, new_column_name) #:nodoc:
        execute("ALTER TABLE #{quote_table_name(table_name)} #{rename_column_sql(table_name, column_name, new_column_name)}")
        rename_column_indexes(table_name, column_name, new_column_name)
      end

      def add_index(table_name, column_name, options = {}) #:nodoc:
        index_name, index_type, index_columns, _, index_algorithm, index_using, comment = add_index_options(table_name, column_name, options)
        sql = "CREATE #{index_type} INDEX #{quote_column_name(index_name)} #{index_using} ON #{quote_table_name(table_name)} (#{index_columns}) #{index_algorithm}"
        execute add_sql_comment!(sql, comment)
      end

      def add_sql_comment!(sql, comment) # :nodoc:
        sql << " COMMENT #{quote(comment)}" if comment
        sql
      end

      def foreign_keys(table_name)
        raise ArgumentError unless table_name.present?

        schema, name = extract_schema_qualified_name(table_name)

        fk_info = select_all(<<-SQL.strip_heredoc, 'SCHEMA')
          SELECT fk.referenced_table_name AS 'to_table',
                 fk.referenced_column_name AS 'primary_key',
                 fk.column_name AS 'column',
                 fk.constraint_name AS 'name',
                 rc.update_rule AS 'on_update',
                 rc.delete_rule AS 'on_delete'
          FROM information_schema.key_column_usage fk
          JOIN information_schema.referential_constraints rc
          USING (constraint_schema, constraint_name)
          WHERE fk.referenced_column_name IS NOT NULL
            AND fk.table_schema = #{quote(schema)}
            AND fk.table_name = #{quote(name)}
        SQL

        fk_info.map do |row|
          options = {
            column: row['column'],
            name: row['name'],
            primary_key: row['primary_key']
          }

          options[:on_update] = extract_foreign_key_action(row['on_update'])
          options[:on_delete] = extract_foreign_key_action(row['on_delete'])

          ForeignKeyDefinition.new(table_name, row['to_table'], options)
        end
      end

      def table_options(table_name)
        create_table_info = create_table_info(table_name)

        # strip create_definitions and partition_options
        raw_table_options = create_table_info.sub(/\A.*\n\) /m, '').sub(/\n\/\*!.*\*\/\n\z/m, '').strip

        # strip AUTO_INCREMENT
        raw_table_options.sub!(/(ENGINE=\w+)(?: AUTO_INCREMENT=\d+)/, '\1')

        # strip COMMENT
        raw_table_options.sub!(/ COMMENT='.+'/, '')

        raw_table_options
      end

      # Maps logical Rails types to MySQL-specific data types.
      def type_to_sql(type, limit = nil, precision = nil, scale = nil, unsigned = nil)
        sql = case type.to_s
        when 'integer'
          integer_to_sql(limit)
        when 'text'
          text_to_sql(limit)
        when 'blob'
          binary_to_sql(limit)
        when 'binary'
          if (0..0xfff) === limit
            "varbinary(#{limit})"
          else
            binary_to_sql(limit)
          end
        else
          super(type, limit, precision, scale)
        end

        sql << ' unsigned' if unsigned && type != :primary_key
        sql
      end

      # SHOW VARIABLES LIKE 'name'
      def show_variable(name)
        select_value("SELECT @@#{name}", 'SCHEMA')
      rescue ActiveRecord::StatementInvalid
        nil
      end

      def primary_keys(table_name) # :nodoc:
        raise ArgumentError unless table_name.present?

        schema, name = extract_schema_qualified_name(table_name)

        select_values(<<-SQL.strip_heredoc, 'SCHEMA')
          SELECT column_name
          FROM information_schema.key_column_usage
          WHERE constraint_name = 'PRIMARY'
            AND table_schema = #{quote(schema)}
            AND table_name = #{quote(name)}
          ORDER BY ordinal_position
        SQL
      end

      def case_sensitive_comparison(table, attribute, column, value)
        if !value.nil? && column.collation && !column.case_sensitive?
          table[attribute].eq(Arel::Nodes::Bin.new(Arel::Nodes::BindParam.new))
        else
          super
        end
      end

      def can_perform_case_insensitive_comparison_for?(column)
        column.case_sensitive?
      end
      private :can_perform_case_insensitive_comparison_for?

      # In MySQL 5.7.5 and up, ONLY_FULL_GROUP_BY affects handling of queries that use
      # DISTINCT and ORDER BY. It requires the ORDER BY columns in the select list for
      # distinct queries, and requires that the ORDER BY include the distinct column.
      # See https://dev.mysql.com/doc/refman/5.7/en/group-by-handling.html
      def columns_for_distinct(columns, orders) # :nodoc:
        order_columns = orders.reject(&:blank?).map { |s|
          # Convert Arel node to string
          s = s.to_sql unless s.is_a?(String)
          # Remove any ASC/DESC modifiers
          s.gsub(/\s+(?:ASC|DESC)\b/i, '')
        }.reject(&:blank?).map.with_index { |column, i| "#{column} AS alias_#{i}" }

        [super, *order_columns].join(', ')
      end

      def strict_mode?
        self.class.type_cast_config_to_boolean(@config.fetch(:strict, true))
      end

      def valid_type?(type)
        !native_database_types[type].nil?
      end

      protected

      def initialize_type_map(m) # :nodoc:
        super

        register_class_with_limit m, %r(char)i, MysqlString

        m.register_type %r(tinytext)i,   Type::Text.new(limit: 2**8 - 1)
        m.register_type %r(tinyblob)i,   Type::Binary.new(limit: 2**8 - 1)
        m.register_type %r(text)i,       Type::Text.new(limit: 2**16 - 1)
        m.register_type %r(blob)i,       Type::Binary.new(limit: 2**16 - 1)
        m.register_type %r(mediumtext)i, Type::Text.new(limit: 2**24 - 1)
        m.register_type %r(mediumblob)i, Type::Binary.new(limit: 2**24 - 1)
        m.register_type %r(longtext)i,   Type::Text.new(limit: 2**32 - 1)
        m.register_type %r(longblob)i,   Type::Binary.new(limit: 2**32 - 1)
        m.register_type %r(^float)i,     Type::Float.new(limit: 24)
        m.register_type %r(^double)i,    Type::Float.new(limit: 53)
        m.register_type %r(^json)i,      MysqlJson.new

        register_integer_type m, %r(^bigint)i,    limit: 8
        register_integer_type m, %r(^int)i,       limit: 4
        register_integer_type m, %r(^mediumint)i, limit: 3
        register_integer_type m, %r(^smallint)i,  limit: 2
        register_integer_type m, %r(^tinyint)i,   limit: 1

        m.register_type %r(^tinyint\(1\))i, Type::Boolean.new if emulate_booleans
        m.alias_type %r(year)i,          'integer'
        m.alias_type %r(bit)i,           'binary'

        m.register_type(%r(enum)i) do |sql_type|
          limit = sql_type[/^enum\((.+)\)/i, 1]
            .split(',').map{|enum| enum.strip.length - 2}.max
          MysqlString.new(limit: limit)
        end

        m.register_type(%r(^set)i) do |sql_type|
          limit = sql_type[/^set\((.+)\)/i, 1]
            .split(',').map{|set| set.strip.length - 1}.sum - 1
          MysqlString.new(limit: limit)
        end
      end

      def register_integer_type(mapping, key, options) # :nodoc:
        mapping.register_type(key) do |sql_type|
          if /\bunsigned\z/ === sql_type
            Type::UnsignedInteger.new(options)
          else
            Type::Integer.new(options)
          end
        end
      end

      def extract_precision(sql_type)
        if /time/ === sql_type
          super || 0
        else
          super
        end
      end

      def fetch_type_metadata(sql_type, extra = "")
        MySQL::TypeMetadata.new(super(sql_type), extra: extra, strict: strict_mode?)
      end

      def add_index_length(option_strings, column_names, options = {})
        if options.is_a?(Hash) && length = options[:length]
          case length
          when Hash
            column_names.each {|name| option_strings[name] += "(#{length[name]})" if length.has_key?(name) && length[name].present?}
          when Integer
            column_names.each {|name| option_strings[name] += "(#{length})"}
          end
        end

        return option_strings
      end

      def quoted_columns_for_index(column_names, options = {})
        option_strings = Hash[column_names.map {|name| [name, '']}]

        # add index length
        option_strings = add_index_length(option_strings, column_names, options)

        # add index sort order
        option_strings = add_index_sort_order(option_strings, column_names, options)

        column_names.map {|name| quote_column_name(name) + option_strings[name]}
      end

      # See https://dev.mysql.com/doc/refman/5.7/en/error-messages-server.html
      ER_DUP_ENTRY            = 1062
      ER_NO_REFERENCED_ROW_2  = 1452
      ER_DATA_TOO_LONG        = 1406
      ER_LOCK_DEADLOCK        = 1213

      def translate_exception(exception, message)
        case error_number(exception)
        when ER_DUP_ENTRY
          RecordNotUnique.new(message)
        when ER_NO_REFERENCED_ROW_2
          InvalidForeignKey.new(message)
        when ER_DATA_TOO_LONG
          ValueTooLong.new(message)
        when ER_LOCK_DEADLOCK
          TransactionSerializationError.new(message)
        else
          super
        end
      end

      def add_column_sql(table_name, column_name, type, options = {})
        td = create_table_definition(table_name)
        cd = td.new_column_definition(column_name, type, options)
        schema_creation.accept(AddColumnDefinition.new(cd))
      end

      def change_column_sql(table_name, column_name, type, options = {})
        column = column_for(table_name, column_name)

        unless options_include_default?(options)
          options[:default] = column.default
        end

        unless options.has_key?(:null)
          options[:null] = column.null
        end

        td = create_table_definition(table_name)
        cd = td.new_column_definition(column.name, type, options)
        schema_creation.accept(ChangeColumnDefinition.new(cd, column.name))
      end

      def rename_column_sql(table_name, column_name, new_column_name)
        column  = column_for(table_name, column_name)
        options = {
          default: column.default,
          null: column.null,
          auto_increment: column.auto_increment?
        }

        current_type = select_one("SHOW COLUMNS FROM #{quote_table_name(table_name)} LIKE '#{column_name}'", 'SCHEMA')["Type"]
        td = create_table_definition(table_name)
        cd = td.new_column_definition(new_column_name, current_type, options)
        schema_creation.accept(ChangeColumnDefinition.new(cd, column.name))
      end

      def remove_column_sql(table_name, column_name, type = nil, options = {})
        "DROP #{quote_column_name(column_name)}"
      end

      def remove_columns_sql(table_name, *column_names)
        column_names.map {|column_name| remove_column_sql(table_name, column_name) }
      end

      def add_index_sql(table_name, column_name, options = {})
        index_name, index_type, index_columns, _, index_algorithm, index_using = add_index_options(table_name, column_name, options)
        index_algorithm[0, 0] = ", " if index_algorithm.present?
        "ADD #{index_type} INDEX #{quote_column_name(index_name)} #{index_using} (#{index_columns})#{index_algorithm}"
      end

      def remove_index_sql(table_name, options = {})
        index_name = index_name_for_remove(table_name, options)
        "DROP INDEX #{index_name}"
      end

      def add_timestamps_sql(table_name, options = {})
        [add_column_sql(table_name, :created_at, :datetime, options), add_column_sql(table_name, :updated_at, :datetime, options)]
      end

      def remove_timestamps_sql(table_name, options = {})
        [remove_column_sql(table_name, :updated_at), remove_column_sql(table_name, :created_at)]
      end

      private

      # MySQL is too stupid to create a temporary table for use subquery, so we have
      # to give it some prompting in the form of a subsubquery. Ugh!
      def subquery_for(key, select)
        subsubselect = select.clone
        subsubselect.projections = [key]

        # Materialize subquery by adding distinct
        # to work with MySQL 5.7.6 which sets optimizer_switch='derived_merge=on'
        subsubselect.distinct unless select.limit || select.offset || select.orders.any?

        subselect = Arel::SelectManager.new(select.engine)
        subselect.project Arel.sql(key.name)
        subselect.from subsubselect.as('__active_record_temp')
      end

      def supports_rename_index?
        mariadb? ? false : version >= '5.7.6'
      end

      def configure_connection
        variables = @config.fetch(:variables, {}).stringify_keys

        # By default, MySQL 'where id is null' selects the last inserted id; Turn this off.
        variables['sql_auto_is_null'] = 0

        # Increase timeout so the server doesn't disconnect us.
        wait_timeout = @config[:wait_timeout]
        wait_timeout = 2147483 unless wait_timeout.is_a?(Integer)
        variables['wait_timeout'] = self.class.type_cast_config_to_integer(wait_timeout)

        defaults = [':default', :default].to_set

        # Make MySQL reject illegal values rather than truncating or blanking them, see
        # http://dev.mysql.com/doc/refman/5.7/en/sql-mode.html#sqlmode_strict_all_tables
        # If the user has provided another value for sql_mode, don't replace it.
        if sql_mode = variables.delete('sql_mode')
          sql_mode = quote(sql_mode)
        elsif !defaults.include?(strict_mode?)
          if strict_mode?
            sql_mode = "CONCAT(@@sql_mode, ',STRICT_ALL_TABLES')"
          else
            sql_mode = "REPLACE(@@sql_mode, 'STRICT_TRANS_TABLES', '')"
            sql_mode = "REPLACE(#{sql_mode}, 'STRICT_ALL_TABLES', '')"
            sql_mode = "REPLACE(#{sql_mode}, 'TRADITIONAL', '')"
          end
          sql_mode = "CONCAT(#{sql_mode}, ',NO_AUTO_VALUE_ON_ZERO')"
        end
        sql_mode_assignment = "@@SESSION.sql_mode = #{sql_mode}, " if sql_mode

        # NAMES does not have an equals sign, see
        # http://dev.mysql.com/doc/refman/5.7/en/set-statement.html#id944430
        # (trailing comma because variable_assignments will always have content)
        if @config[:encoding]
          encoding = "NAMES #{@config[:encoding]}"
          encoding << " COLLATE #{@config[:collation]}" if @config[:collation]
          encoding << ", "
        end

        # Gather up all of the SET variables...
        variable_assignments = variables.map do |k, v|
          if defaults.include?(v)
            "@@SESSION.#{k} = DEFAULT" # Sets the value to the global or compile default
          elsif !v.nil?
            "@@SESSION.#{k} = #{quote(v)}"
          end
          # or else nil; compact to clear nils out
        end.compact.join(', ')

        # ...and send them all in one query
        @connection.query  "SET #{encoding} #{sql_mode_assignment} #{variable_assignments}"
      end

      def column_definitions(table_name) # :nodoc:
        execute_and_free("SHOW FULL FIELDS FROM #{quote_table_name(table_name)}", 'SCHEMA') do |result|
          each_hash(result)
        end
      end

      def extract_foreign_key_action(specifier) # :nodoc:
        case specifier
        when 'CASCADE'; :cascade
        when 'SET NULL'; :nullify
        end
      end

      def create_table_info(table_name) # :nodoc:
        select_one("SHOW CREATE TABLE #{quote_table_name(table_name)}")["Create Table"]
      end

      def create_table_definition(*args) # :nodoc:
        MySQL::TableDefinition.new(*args)
      end

      def extract_schema_qualified_name(string) # :nodoc:
        schema, name = string.to_s.scan(/[^`.\s]+|`[^`]*`/)
        schema, name = @config[:database], schema unless name
        [schema, name]
      end

      def integer_to_sql(limit) # :nodoc:
        case limit
        when 1; 'tinyint'
        when 2; 'smallint'
        when 3; 'mediumint'
        when nil, 4; 'int'
        when 5..8; 'bigint'
        else raise(ActiveRecordError, "No integer type has byte size #{limit}")
        end
      end

      def text_to_sql(limit) # :nodoc:
        case limit
        when 0..0xff;               'tinytext'
        when nil, 0x100..0xffff;    'text'
        when 0x10000..0xffffff;     'mediumtext'
        when 0x1000000..0xffffffff; 'longtext'
        else raise(ActiveRecordError, "No text type has byte length #{limit}")
        end
      end

      def binary_to_sql(limit) # :nodoc:
        case limit
        when 0..0xff;               'tinyblob'
        when nil, 0x100..0xffff;    'blob'
        when 0x10000..0xffffff;     'mediumblob'
        when 0x1000000..0xffffffff; 'longblob'
        else raise(ActiveRecordError, "No binary type has byte length #{limit}")
        end
      end

      class MysqlJson < Type::Internal::AbstractJson # :nodoc:
        def changed_in_place?(raw_old_value, new_value)
          # Normalization is required because MySQL JSON data format includes
          # the space between the elements.
          super(serialize(deserialize(raw_old_value)), new_value)
        end
      end

      class MysqlString < Type::String # :nodoc:
        def serialize(value)
          case value
          when true then MySQL::Quoting::QUOTED_TRUE
          when false then MySQL::Quoting::QUOTED_FALSE
          else super
          end
        end

        private

        def cast_value(value)
          case value
          when true then MySQL::Quoting::QUOTED_TRUE
          when false then MySQL::Quoting::QUOTED_FALSE
          else super
          end
        end
      end

      ActiveRecord::Type.register(:json, MysqlJson, adapter: :mysql2)
      ActiveRecord::Type.register(:string, MysqlString, adapter: :mysql2)
      ActiveRecord::Type.register(:unsigned_integer, Type::UnsignedInteger, adapter: :mysql2)
    end
  end
end
