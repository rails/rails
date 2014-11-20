require 'arel/visitors/bind_visitor'

module ActiveRecord
  module ConnectionAdapters
    class AbstractMysqlAdapter < AbstractAdapter
      include Savepoints

      class SchemaCreation < AbstractAdapter::SchemaCreation

        def visit_AddColumn(o)
          add_column_position!(super, column_options(o))
        end

        private
        def visit_ChangeColumnDefinition(o)
          column = o.column
          options = o.options
          sql_type = type_to_sql(o.type, options[:limit], options[:precision], options[:scale])
          change_column_sql = "CHANGE #{quote_column_name(column.name)} #{quote_column_name(options[:name])} #{sql_type}"
          add_column_options!(change_column_sql, options.merge(column: column))
          add_column_position!(change_column_sql, options)
        end

        def add_column_position!(sql, options)
          if options[:first]
            sql << " FIRST"
          elsif options[:after]
            sql << " AFTER #{quote_column_name(options[:after])}"
          end
          sql
        end
      end

      def schema_creation
        SchemaCreation.new self
      end

      class Column < ConnectionAdapters::Column # :nodoc:
        attr_reader :collation, :strict, :extra

        def initialize(name, default, sql_type = nil, null = true, collation = nil, strict = false, extra = "")
          @strict    = strict
          @collation = collation
          @extra     = extra
          super(name, default, sql_type, null)
        end

        def extract_default(default)
          if blob_or_text_column?
            if default.blank?
              null || strict ? nil : ''
            else
              raise ArgumentError, "#{type} columns cannot have a default value: #{default.inspect}"
            end
          elsif missing_default_forged_as_empty_string?(default)
            nil
          else
            super
          end
        end

        def has_default?
          return false if blob_or_text_column? #mysql forbids defaults on blob and text columns
          super
        end

        def blob_or_text_column?
          sql_type =~ /blob/i || type == :text
        end

        # Must return the relevant concrete adapter
        def adapter
          raise NotImplementedError
        end

        def case_sensitive?
          collation && !collation.match(/_ci$/)
        end

        private

        def simplified_type(field_type)
          return :boolean if adapter.emulate_booleans && field_type.downcase.index("tinyint(1)")

          case field_type
          when /enum/i, /set/i then :string
          when /year/i         then :integer
          when /bit/i          then :binary
          else
            super
          end
        end

        def extract_limit(sql_type)
          case sql_type
          when /^enum\((.+)\)/i
            $1.split(',').map{|enum| enum.strip.length - 2}.max
          when /blob|text/i
            case sql_type
            when /tiny/i
              255
            when /medium/i
              16777215
            when /long/i
              2147483647 # mysql only allows 2^31-1, not 2^32-1, somewhat inconsistently with the tiny/medium/normal cases
            else
              super # we could return 65535 here, but we leave it undecorated by default
            end
          when /^bigint/i;    8
          when /^int/i;       4
          when /^mediumint/i; 3
          when /^smallint/i;  2
          when /^tinyint/i;   1
          when /^float/i;     24
          when /^double/i;    53
          else
            super
          end
        end

        # MySQL misreports NOT NULL column default when none is given.
        # We can't detect this for columns which may have a legitimate ''
        # default (string) but we can for others (integer, datetime, boolean,
        # and the rest).
        #
        # Test whether the column has default '', is not null, and is not
        # a type allowing default ''.
        def missing_default_forged_as_empty_string?(default)
          type != :string && !null && default == ''
        end
      end

      ##
      # :singleton-method:
      # By default, the MysqlAdapter will consider all columns of type <tt>tinyint(1)</tt>
      # as boolean. If you wish to disable this emulation (which was the default
      # behavior in versions 0.13.1 and earlier) you can add the following line
      # to your application.rb file:
      #
      #   ActiveRecord::ConnectionAdapters::Mysql[2]Adapter.emulate_booleans = false
      class_attribute :emulate_booleans
      self.emulate_booleans = true

      LOST_CONNECTION_ERROR_MESSAGES = [
        "Server shutdown in progress",
        "Broken pipe",
        "Lost connection to MySQL server during query",
        "MySQL server has gone away" ]

      QUOTED_TRUE, QUOTED_FALSE = '1', '0'

      NATIVE_DATABASE_TYPES = {
        :primary_key => "int(11) auto_increment PRIMARY KEY",
        :string      => { :name => "varchar", :limit => 255 },
        :text        => { :name => "text" },
        :integer     => { :name => "int", :limit => 4 },
        :float       => { :name => "float" },
        :decimal     => { :name => "decimal" },
        :datetime    => { :name => "datetime" },
        :timestamp   => { :name => "datetime" },
        :time        => { :name => "time" },
        :date        => { :name => "date" },
        :binary      => { :name => "blob" },
        :boolean     => { :name => "tinyint", :limit => 1 }
      }

      INDEX_TYPES  = [:fulltext, :spatial]
      INDEX_USINGS = [:btree, :hash]

      class BindSubstitution < Arel::Visitors::MySQL # :nodoc:
        include Arel::Visitors::BindVisitor
      end

      # FIXME: Make the first parameter more similar for the two adapters
      def initialize(connection, logger, connection_options, config)
        super(connection, logger)
        @connection_options, @config = connection_options, config
        @quoted_column_names, @quoted_table_names = {}, {}

        if self.class.type_cast_config_to_boolean(config.fetch(:prepared_statements) { true })
          @prepared_statements = true
          @visitor = Arel::Visitors::MySQL.new self
        else
          @visitor = unprepared_visitor
        end
      end

      def adapter_name #:nodoc:
        self.class::ADAPTER_NAME
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

      # Technically MySQL allows to create indexes with the sort order syntax
      # but at the moment (5.5) it doesn't yet implement them
      def supports_index_sort_order?
        true
      end

      def type_cast(value, column)
        case value
        when TrueClass
          1
        when FalseClass
          0
        else
          super
        end
      end

      # MySQL 4 technically support transaction isolation, but it is affected by a bug
      # where the transaction level gets persisted for the whole session:
      #
      # http://bugs.mysql.com/bug.php?id=39170
      def supports_transaction_isolation?
        version[0] >= 5
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

      # Overridden by the adapters to instantiate their specific Column type.
      def new_column(field, default, type, null, collation, extra = "") # :nodoc:
        Column.new(field, default, type, null, collation, extra)
      end

      # Must return the Mysql error number from the exception, if the exception has an
      # error number.
      def error_number(exception) # :nodoc:
        raise NotImplementedError
      end

      # QUOTING ==================================================

      def quote(value, column = nil)
        if value.kind_of?(String) && column && column.type == :binary
          s = value.unpack("H*")[0]
          "x'#{s}'"
        elsif value.kind_of?(BigDecimal)
          value.to_s("F")
        else
          super
        end
      end

      def quote_column_name(name) #:nodoc:
        @quoted_column_names[name] ||= "`#{name.to_s.gsub('`', '``')}`"
      end

      def quote_table_name(name) #:nodoc:
        @quoted_table_names[name] ||= quote_column_name(name).gsub('.', '`.`')
      end

      def quoted_true
        QUOTED_TRUE
      end

      def quoted_false
        QUOTED_FALSE
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

      # DATABASE STATEMENTS ======================================

      # Executes the SQL statement in the context of this connection.
      def execute(sql, name = nil)
        log(sql, name) { @connection.query(sql) }
      end

      # MysqlAdapter has to free a result after using it, so we use this method to write
      # stuff in an abstract way without concerning ourselves about whether it needs to be
      # explicitly freed or not.
      def execute_and_free(sql, name = nil) #:nodoc:
        yield execute(sql, name)
      end

      def update_sql(sql, name = nil) #:nodoc:
        super
        @connection.affected_rows
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

      def rollback_db_transaction #:nodoc:
        execute "ROLLBACK"
      end

      # In the simple case, MySQL allows us to place JOINs directly into the UPDATE
      # query. However, this does not allow for LIMIT, OFFSET and ORDER. To support
      # these, we must use a subquery.
      def join_to_update(update, select) #:nodoc:
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
          execute "CREATE DATABASE `#{name}` DEFAULT CHARACTER SET `#{options[:charset] || 'utf8'}` COLLATE `#{options[:collation]}`"
        else
          execute "CREATE DATABASE `#{name}` DEFAULT CHARACTER SET `#{options[:charset] || 'utf8'}`"
        end
      end

      # Drops a MySQL database.
      #
      # Example:
      #   drop_database('sebastian_development')
      def drop_database(name) #:nodoc:
        execute "DROP DATABASE IF EXISTS `#{name}`"
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

      def tables(name = nil, database = nil, like = nil) #:nodoc:
        sql = "SHOW TABLES "
        sql << "IN #{quote_table_name(database)} " if database
        sql << "LIKE #{quote(like)}" if like

        execute_and_free(sql, 'SCHEMA') do |result|
          result.collect { |field| field.first }
        end
      end

      def table_exists?(name)
        return false unless name
        return true if tables(nil, nil, name).any?

        name          = name.to_s
        schema, table = name.split('.', 2)

        unless table # A table was provided without a schema
          table  = schema
          schema = nil
        end

        tables(nil, schema, table).any?
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
              indexes << IndexDefinition.new(row[:Table], row[:Key_name], row[:Non_unique].to_i == 0, [], [], nil, nil, index_type, index_using)
            end

            indexes.last.columns << row[:Column_name]
            indexes.last.lengths << row[:Sub_part]
          end
        end

        indexes
      end

      # Returns an array of +Column+ objects for the table specified by +table_name+.
      def columns(table_name)#:nodoc:
        sql = "SHOW FULL FIELDS FROM #{quote_table_name(table_name)}"
        execute_and_free(sql, 'SCHEMA') do |result|
          each_hash(result).map do |field|
            field_name = set_field_encoding(field[:Field])
            new_column(field_name, field[:Default], field[:Type], field[:Null] == "YES", field[:Collation], field[:Extra])
          end
        end
      end

      def create_table(table_name, options = {}) #:nodoc:
        super(table_name, options.reverse_merge(:options => "ENGINE=InnoDB"))
      end

      def bulk_change_table(table_name, operations) #:nodoc:
        sqls = operations.map do |command, args|
          table, arguments = args.shift, args
          method = :"#{command}_sql"

          if respond_to?(method, true)
            send(method, table, *arguments)
          else
            raise "Unknown method called : #{method}(#{arguments.inspect})"
          end
        end.flatten.join(", ")

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

      def drop_table(table_name, options = {})
        execute "DROP#{' TEMPORARY' if options[:temporary]} TABLE #{quote_table_name(table_name)}"
      end

      def rename_index(table_name, old_name, new_name)
        if supports_rename_index?
          execute "ALTER TABLE #{quote_table_name(table_name)} RENAME INDEX #{quote_table_name(old_name)} TO #{quote_table_name(new_name)}"
        else
          super
        end
      end

      def change_column_default(table_name, column_name, default)
        column = column_for(table_name, column_name)
        change_column table_name, column_name, column.sql_type, :default => default
      end

      def change_column_null(table_name, column_name, null, default = nil)
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
        index_name, index_type, index_columns, index_options, index_algorithm, index_using = add_index_options(table_name, column_name, options)
        execute "CREATE #{index_type} INDEX #{quote_column_name(index_name)} #{index_using} ON #{quote_table_name(table_name)} (#{index_columns})#{index_options} #{index_algorithm}"
      end

      # Maps logical Rails types to MySQL-specific data types.
      def type_to_sql(type, limit = nil, precision = nil, scale = nil)
        case type.to_s
        when 'binary'
          case limit
          when 0..0xfff;           "varbinary(#{limit})"
          when nil;                "blob"
          when 0x1000..0xffffffff; "blob(#{limit})"
          else raise(ActiveRecordError, "No binary type has character length #{limit}")
          end
        when 'integer'
          case limit
          when 1; 'tinyint'
          when 2; 'smallint'
          when 3; 'mediumint'
          when nil, 4, 11; 'int(11)'  # compatibility with MySQL default
          when 5..8; 'bigint'
          else raise(ActiveRecordError, "No integer type has byte size #{limit}")
          end
        when 'text'
          case limit
          when 0..0xff;               'tinytext'
          when nil, 0x100..0xffff;    'text'
          when 0x10000..0xffffff;     'mediumtext'
          when 0x1000000..0xffffffff; 'longtext'
          else raise(ActiveRecordError, "No text type has character length #{limit}")
          end
        else
          super
        end
      end

      def add_column_position!(sql, options)
        if options[:first]
          sql << " FIRST"
        elsif options[:after]
          sql << " AFTER #{quote_column_name(options[:after])}"
        end
      end

      # SHOW VARIABLES LIKE 'name'
      def show_variable(name)
        variables = select_all("SHOW VARIABLES LIKE '#{name}'", 'SCHEMA')
        variables.first['Value'] unless variables.empty?
      end

      # Returns a table's primary key and belonging sequence.
      def pk_and_sequence_for(table)
        execute_and_free("SHOW CREATE TABLE #{quote_table_name(table)}", 'SCHEMA') do |result|
          create_table = each_hash(result).first[:"Create Table"]
          if create_table.to_s =~ /PRIMARY KEY\s+(?:USING\s+\w+\s+)?\((.+)\)/
            keys = $1.split(",").map { |key| key.delete('`"') }
            keys.length == 1 ? [keys.first, nil] : nil
          else
            nil
          end
        end
      end

      # Returns just a table's primary key
      def primary_key(table)
        pk_and_sequence = pk_and_sequence_for(table)
        pk_and_sequence && pk_and_sequence.first
      end

      def case_sensitive_modifier(node)
        Arel::Nodes::Bin.new(node)
      end

      def case_insensitive_comparison(table, attribute, column, value)
        if column.case_sensitive?
          super
        else
          table[attribute].eq(value)
        end
      end

      def limited_update_conditions(where_sql, quoted_table_name, quoted_primary_key)
        where_sql
      end

      def strict_mode?
        self.class.type_cast_config_to_boolean(@config.fetch(:strict, true))
      end

      def valid_type?(type)
        !native_database_types[type].nil?
      end

      protected

      # MySQL is too stupid to create a temporary table for use subquery, so we have
      # to give it some prompting in the form of a subsubquery. Ugh!
      def subquery_for(key, select)
        subsubselect = select.clone
        subsubselect.projections = [key]

        subselect = Arel::SelectManager.new(select.engine)
        subselect.project Arel.sql(key.name)
        subselect.from subsubselect.as('__active_record_temp')
      end

      def add_index_length(option_strings, column_names, options = {})
        if options.is_a?(Hash) && length = options[:length]
          case length
          when Hash
            column_names.each {|name| option_strings[name] += "(#{length[name]})" if length.has_key?(name) && length[name].present?}
          when Fixnum
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

      def translate_exception(exception, message)
        case error_number(exception)
        when 1062
          RecordNotUnique.new(message, exception)
        when 1452
          InvalidForeignKey.new(message, exception)
        else
          super
        end
      end

      def add_column_sql(table_name, column_name, type, options = {})
        td = create_table_definition table_name, options[:temporary], options[:options]
        cd = td.new_column_definition(column_name, type, options)
        schema_creation.visit_AddColumn cd
      end

      def change_column_sql(table_name, column_name, type, options = {})
        column = column_for(table_name, column_name)

        unless options_include_default?(options)
          options[:default] = column.default
        end

        unless options.has_key?(:null)
          options[:null] = column.null
        end

        options[:name] = column.name
        schema_creation.accept ChangeColumnDefinition.new column, type, options
      end

      def rename_column_sql(table_name, column_name, new_column_name)
        options = { name: new_column_name }

        if column = columns(table_name).find { |c| c.name == column_name.to_s }
          options[:default] = column.default
          options[:null] = column.null
          options[:auto_increment] = (column.extra == "auto_increment")
        else
          raise ActiveRecordError, "No such column: #{table_name}.#{column_name}"
        end

        current_type = select_one("SHOW COLUMNS FROM #{quote_table_name(table_name)} LIKE '#{column_name}'", 'SCHEMA')["Type"]
        schema_creation.accept ChangeColumnDefinition.new column, current_type, options
      end

      def remove_column_sql(table_name, column_name, type = nil, options = {})
        "DROP #{quote_column_name(column_name)}"
      end

      def remove_columns_sql(table_name, *column_names)
        column_names.map {|column_name| remove_column_sql(table_name, column_name) }
      end

      def add_index_sql(table_name, column_name, options = {})
        index_name, index_type, index_columns = add_index_options(table_name, column_name, options)
        "ADD #{index_type} INDEX #{index_name} (#{index_columns})"
      end

      def remove_index_sql(table_name, options = {})
        index_name = index_name_for_remove(table_name, options)
        "DROP INDEX #{index_name}"
      end

      def add_timestamps_sql(table_name, options = {})
        [add_column_sql(table_name, :created_at, :datetime, options), add_column_sql(table_name, :updated_at, :datetime, options)]
      end

      def remove_timestamps_sql(table_name)
        [remove_column_sql(table_name, :updated_at), remove_column_sql(table_name, :created_at)]
      end

      private

      def version
        @version ||= full_version.scan(/^(\d+)\.(\d+)\.(\d+)/).flatten.map { |v| v.to_i }
      end

      def mariadb?
        full_version =~ /mariadb/i
      end

      def supports_views?
        version[0] >= 5
      end

      def supports_rename_index?
        mariadb? ? false : (version[0] == 5 && version[1] >= 7) || version[0] >= 6
      end

      def column_for(table_name, column_name)
        unless column = columns(table_name).find { |c| c.name == column_name.to_s }
          raise "No such column: #{table_name}.#{column_name}"
        end
        column
      end

      def configure_connection
        variables = @config.fetch(:variables, {}).stringify_keys

        # By default, MySQL 'where id is null' selects the last inserted id.
        # Turn this off. http://dev.rubyonrails.org/ticket/6778
        variables['sql_auto_is_null'] = 0

        # Increase timeout so the server doesn't disconnect us.
        wait_timeout = @config[:wait_timeout]
        wait_timeout = 2147483 unless wait_timeout.is_a?(Fixnum)
        variables['wait_timeout'] = self.class.type_cast_config_to_integer(wait_timeout)

        # Make MySQL reject illegal values rather than truncating or blanking them, see
        # http://dev.mysql.com/doc/refman/5.0/en/server-sql-mode.html#sqlmode_strict_all_tables
        # If the user has provided another value for sql_mode, don't replace it.
        unless variables.has_key?('sql_mode')
          variables['sql_mode'] = strict_mode? ? 'STRICT_ALL_TABLES' : ''
        end

        # NAMES does not have an equals sign, see
        # http://dev.mysql.com/doc/refman/5.0/en/set-statement.html#id944430
        # (trailing comma because variable_assignments will always have content)
        encoding = "NAMES #{@config[:encoding]}, " if @config[:encoding]

        # Gather up all of the SET variables...
        variable_assignments = variables.map do |k, v|
          if v == ':default' || v == :default
            "@@SESSION.#{k.to_s} = DEFAULT" # Sets the value to the global or compile default
          elsif !v.nil?
            "@@SESSION.#{k.to_s} = #{quote(v)}"
          end
          # or else nil; compact to clear nils out
        end.compact.join(', ')

        # ...and send them all in one query
        @connection.query  "SET #{encoding} #{variable_assignments}"
      end
    end
  end
end
