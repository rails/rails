require 'active_record/connection_adapters/abstract_adapter'
require 'active_support/core_ext/kernel/requires'
require 'active_support/core_ext/object/blank'
require 'set'
require 'active_record/connection_adapters/statement_pool'

gem 'mysql', '~> 2.8.1'
require 'mysql'

class Mysql
  class Time
    ###
    # This monkey patch is for test_additional_columns_from_join_table
    def to_date
      Date.new(year, month, day)
    end
  end
  class Stmt; include Enumerable end
  class Result; include Enumerable end
end

module ActiveRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects.
    def self.mysql_connection(config) # :nodoc:
      config = config.symbolize_keys
      host     = config[:host]
      port     = config[:port]
      socket   = config[:socket]
      username = config[:username] ? config[:username].to_s : 'root'
      password = config[:password].to_s
      database = config[:database]

      mysql = Mysql.init
      mysql.ssl_set(config[:sslkey], config[:sslcert], config[:sslca], config[:sslcapath], config[:sslcipher]) if config[:sslca] || config[:sslkey]

      default_flags = Mysql.const_defined?(:CLIENT_MULTI_RESULTS) ? Mysql::CLIENT_MULTI_RESULTS : 0
      default_flags |= Mysql::CLIENT_FOUND_ROWS if Mysql.const_defined?(:CLIENT_FOUND_ROWS)
      options = [host, username, password, database, port, socket, default_flags]
      ConnectionAdapters::MysqlAdapter.new(mysql, logger, options, config)
    end
  end

  module ConnectionAdapters
    class MysqlColumn < Column #:nodoc:
      class << self
        def string_to_time(value)
          return super unless Mysql::Time === value
          new_time(
            value.year,
            value.month,
            value.day,
            value.hour,
            value.minute,
            value.second,
            value.second_part)
        end

        def string_to_dummy_time(v)
          return super unless Mysql::Time === v
          new_time(2000, 01, 01, v.hour, v.minute, v.second, v.second_part)
        end

        def string_to_date(v)
          return super unless Mysql::Time === v
          new_date(v.year, v.month, v.day)
        end
      end

      def extract_default(default)
        if sql_type =~ /blob/i || type == :text
          if default.blank?
            return null ? nil : ''
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
        return false if sql_type =~ /blob/i || type == :text #mysql forbids defaults on blob and text columns
        super
      end

      private
        def simplified_type(field_type)
          return :boolean if MysqlAdapter.emulate_booleans && field_type.downcase.index("tinyint(1)")
          return :string  if field_type =~ /enum/i
          super
        end

        def extract_limit(sql_type)
          case sql_type
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

    # The MySQL adapter will work with both Ruby/MySQL, which is a Ruby-based MySQL adapter that comes bundled with Active Record, and with
    # the faster C-based MySQL/Ruby adapter (available both as a gem and from http://www.tmtm.org/en/mysql/ruby/).
    #
    # Options:
    #
    # * <tt>:host</tt> - Defaults to "localhost".
    # * <tt>:port</tt> - Defaults to 3306.
    # * <tt>:socket</tt> - Defaults to "/tmp/mysql.sock".
    # * <tt>:username</tt> - Defaults to "root"
    # * <tt>:password</tt> - Defaults to nothing.
    # * <tt>:database</tt> - The name of the database. No default, must be provided.
    # * <tt>:encoding</tt> - (Optional) Sets the client encoding by executing "SET NAMES <encoding>" after connection.
    # * <tt>:reconnect</tt> - Defaults to false (See MySQL documentation: http://dev.mysql.com/doc/refman/5.0/en/auto-reconnect.html).
    # * <tt>:sslca</tt> - Necessary to use MySQL with an SSL connection.
    # * <tt>:sslkey</tt> - Necessary to use MySQL with an SSL connection.
    # * <tt>:sslcert</tt> - Necessary to use MySQL with an SSL connection.
    # * <tt>:sslcapath</tt> - Necessary to use MySQL with an SSL connection.
    # * <tt>:sslcipher</tt> - Necessary to use MySQL with an SSL connection.
    #
    class MysqlAdapter < AbstractAdapter

      ##
      # :singleton-method:
      # By default, the MysqlAdapter will consider all columns of type <tt>tinyint(1)</tt>
      # as boolean. If you wish to disable this emulation (which was the default
      # behavior in versions 0.13.1 and earlier) you can add the following line
      # to your application.rb file:
      #
      #   ActiveRecord::ConnectionAdapters::MysqlAdapter.emulate_booleans = false
      cattr_accessor :emulate_booleans
      self.emulate_booleans = true

      ADAPTER_NAME = 'MySQL'

      LOST_CONNECTION_ERROR_MESSAGES = [
        "Server shutdown in progress",
        "Broken pipe",
        "Lost connection to MySQL server during query",
        "MySQL server has gone away" ]

      QUOTED_TRUE, QUOTED_FALSE = '1', '0'

      NATIVE_DATABASE_TYPES = {
        :primary_key => "int(11) DEFAULT NULL auto_increment PRIMARY KEY",
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

      class StatementPool < ConnectionAdapters::StatementPool
        def initialize(connection, max = 1000)
          super
          @cache = Hash.new { |h,pid| h[pid] = {} }
        end

        def each(&block); cache.each(&block); end
        def key?(key);    cache.key?(key); end
        def [](key);      cache[key]; end
        def length;       cache.length; end
        def delete(key);  cache.delete(key); end

        def []=(sql, key)
          while @max <= cache.size
            cache.shift.last[:stmt].close
          end
          cache[sql] = key
        end

        def clear
          cache.values.each do |hash|
            hash[:stmt].close
          end
          cache.clear
        end

        private
        def cache
          @cache[$$]
        end
      end

      def initialize(connection, logger, connection_options, config)
        super(connection, logger)
        @connection_options, @config = connection_options, config
        @quoted_column_names, @quoted_table_names = {}, {}
        @statements = {}
        @statements = StatementPool.new(@connection,
                                        config.fetch(:statement_limit) { 1000 })
        @client_encoding = nil
        connect
      end

      def self.visitor_for(pool) # :nodoc:
        Arel::Visitors::MySQL.new(pool)
      end

      def adapter_name #:nodoc:
        ADAPTER_NAME
      end

      def supports_bulk_alter? #:nodoc:
        true
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

      # Returns true, since this connection adapter supports savepoints.
      def supports_savepoints? #:nodoc:
        true
      end

      def native_database_types #:nodoc:
        NATIVE_DATABASE_TYPES
      end


      # QUOTING ==================================================

      def quote(value, column = nil)
        if value.kind_of?(String) && column && column.type == :binary && column.class.respond_to?(:string_to_binary)
          s = column.class.string_to_binary(value).unpack("H*")[0]
          "x'#{s}'"
        elsif value.kind_of?(BigDecimal)
          value.to_s("F")
        else
          super
        end
      end

      def type_cast(value, column)
        return super unless value == true || value == false

        value ? 1 : 0
      end

      def quote_column_name(name) #:nodoc:
        @quoted_column_names[name] ||= "`#{name.to_s.gsub('`', '``')}`"
      end

      def quote_table_name(name) #:nodoc:
        @quoted_table_names[name] ||= quote_column_name(name).gsub('.', '`.`')
      end

      def quote_string(string) #:nodoc:
        @connection.quote(string)
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

      # CONNECTION MANAGEMENT ====================================

      def active?
        if @connection.respond_to?(:stat)
          @connection.stat
        else
          @connection.query 'select 1'
        end

        # mysql-ruby doesn't raise an exception when stat fails.
        if @connection.respond_to?(:errno)
          @connection.errno.zero?
        else
          true
        end
      rescue Mysql::Error
        false
      end

      def reconnect!
        disconnect!
        clear_cache!
        connect
      end

      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        @connection.close rescue nil
      end

      def reset!
        if @connection.respond_to?(:change_user)
          # See http://bugs.mysql.com/bug.php?id=33540 -- the workaround way to
          # reset the connection is to change the user to the same user.
          @connection.change_user(@config[:username], @config[:password], @config[:database])
          configure_connection
        end
      end

      # DATABASE STATEMENTS ======================================

      def select_rows(sql, name = nil)
        @connection.query_with_result = true
        rows = exec_without_stmt(sql, name).rows
        @connection.more_results && @connection.next_result    # invoking stored procedures with CLIENT_MULTI_RESULTS requires this to tidy up else connection will be dropped
        rows
      end

      # Clears the prepared statements cache.
      def clear_cache!
        @statements.clear
      end

      if "<3".respond_to?(:encode)
        # Taken from here:
        #   https://github.com/tmtm/ruby-mysql/blob/master/lib/mysql/charset.rb
        # Author: TOMITA Masahiro <tommy@tmtm.org>
        ENCODINGS = {
          "armscii8" => nil,
          "ascii"    => Encoding::US_ASCII,
          "big5"     => Encoding::Big5,
          "binary"   => Encoding::ASCII_8BIT,
          "cp1250"   => Encoding::Windows_1250,
          "cp1251"   => Encoding::Windows_1251,
          "cp1256"   => Encoding::Windows_1256,
          "cp1257"   => Encoding::Windows_1257,
          "cp850"    => Encoding::CP850,
          "cp852"    => Encoding::CP852,
          "cp866"    => Encoding::IBM866,
          "cp932"    => Encoding::Windows_31J,
          "dec8"     => nil,
          "eucjpms"  => Encoding::EucJP_ms,
          "euckr"    => Encoding::EUC_KR,
          "gb2312"   => Encoding::EUC_CN,
          "gbk"      => Encoding::GBK,
          "geostd8"  => nil,
          "greek"    => Encoding::ISO_8859_7,
          "hebrew"   => Encoding::ISO_8859_8,
          "hp8"      => nil,
          "keybcs2"  => nil,
          "koi8r"    => Encoding::KOI8_R,
          "koi8u"    => Encoding::KOI8_U,
          "latin1"   => Encoding::ISO_8859_1,
          "latin2"   => Encoding::ISO_8859_2,
          "latin5"   => Encoding::ISO_8859_9,
          "latin7"   => Encoding::ISO_8859_13,
          "macce"    => Encoding::MacCentEuro,
          "macroman" => Encoding::MacRoman,
          "sjis"     => Encoding::SHIFT_JIS,
          "swe7"     => nil,
          "tis620"   => Encoding::TIS_620,
          "ucs2"     => Encoding::UTF_16BE,
          "ujis"     => Encoding::EucJP_ms,
          "utf8"     => Encoding::UTF_8,
          "utf8mb4"  => Encoding::UTF_8,
        }
      else
        ENCODINGS = Hash.new { |h,k| h[k] = k }
      end

      # Get the client encoding for this database
      def client_encoding
        return @client_encoding if @client_encoding

        result = exec_query(
          "SHOW VARIABLES WHERE Variable_name = 'character_set_client'",
          'SCHEMA')
        @client_encoding = ENCODINGS[result.rows.last.last]
      end

      def exec_query(sql, name = 'SQL', binds = [])
        log(sql, name, binds) do
          exec_stmt(sql, name, binds) do |cols, stmt|
            ActiveRecord::Result.new(cols, stmt.to_a) if cols
          end
        end
      end

      def last_inserted_id(result)
        @connection.insert_id
      end

      def exec_without_stmt(sql, name = 'SQL') # :nodoc:
        # Some queries, like SHOW CREATE TABLE don't work through the prepared
        # statement API.  For those queries, we need to use this method. :'(
        log(sql, name) do
          result = @connection.query(sql)
          cols = []
          rows = []

          if result
            cols = result.fetch_fields.map { |field| field.name }
            rows = result.to_a
            result.free
          end
          ActiveRecord::Result.new(cols, rows)
        end
      end

      # Executes an SQL query and returns a MySQL::Result object. Note that you have to free
      # the Result object after you're done using it.
      def execute(sql, name = nil) #:nodoc:
        if name == :skip_logging
          @connection.query(sql)
        else
          log(sql, name) { @connection.query(sql) }
        end
      rescue ActiveRecord::StatementInvalid => exception
        if exception.message.split(":").first =~ /Packets out of order/
          raise ActiveRecord::StatementInvalid, "'Packets out of order' error was received from the database. Please update your mysql bindings (gem install mysql) and read http://dev.mysql.com/doc/mysql/en/password-hashing.html for more information.  If you're on Windows, use the Instant Rails installer to get the updated mysql bindings."
        else
          raise
        end
      end

      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
        super sql, name
        id_value || @connection.insert_id
      end
      alias :create :insert_sql

      def update_sql(sql, name = nil) #:nodoc:
        super
        @connection.affected_rows
      end

      def exec_delete(sql, name, binds)
        log(sql, name, binds) do
          exec_stmt(sql, name, binds) do |cols, stmt|
            stmt.affected_rows
          end
        end
      end
      alias :exec_update :exec_delete

      def begin_db_transaction #:nodoc:
        exec_without_stmt "BEGIN"
      rescue Mysql::Error
        # Transactions aren't supported
      end

      def commit_db_transaction #:nodoc:
        execute "COMMIT"
      rescue Exception
        # Transactions aren't supported
      end

      def rollback_db_transaction #:nodoc:
        execute "ROLLBACK"
      rescue Exception
        # Transactions aren't supported
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

      def add_limit_offset!(sql, options) #:nodoc:
        limit, offset = options[:limit], options[:offset]
        if limit && offset
          sql << " LIMIT #{offset.to_i}, #{sanitize_limit(limit)}"
        elsif limit
          sql << " LIMIT #{sanitize_limit(limit)}"
        elsif offset
          sql << " OFFSET #{offset.to_i}"
        end
        sql
      end
      deprecate :add_limit_offset!

      # In the simple case, MySQL allows us to place JOINs directly into the UPDATE
      # query. However, this does not allow for LIMIT, OFFSET and ORDER. To support
      # these, we must use a subquery. However, MySQL is too stupid to create a
      # temporary table for this automatically, so we have to give it some prompting
      # in the form of a subsubquery. Ugh!
      def join_to_update(update, select) #:nodoc:
        if select.limit || select.offset || select.orders.any?
          subsubselect = select.clone
          subsubselect.projections = [update.key]

          subselect = Arel::SelectManager.new(select.engine)
          subselect.project Arel.sql(update.key.name)
          subselect.from subsubselect.as('__active_record_temp')

          update.where update.key.in(subselect)
        else
          update.table select.source
          update.wheres = select.constraints
        end
      end

      # SCHEMA STATEMENTS ========================================

      def structure_dump #:nodoc:
        if supports_views?
          sql = "SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'"
        else
          sql = "SHOW TABLES"
        end

        select_all(sql).map do |table|
          table.delete('Table_type')
          sql = "SHOW CREATE TABLE #{quote_table_name(table.to_a.first.last)}"
          exec_without_stmt(sql).first['Create Table'] + ";\n\n"
        end.join("")
      end

      # Drops the database specified on the +name+ attribute
      # and creates it again using the provided +options+.
      def recreate_database(name, options = {}) #:nodoc:
        drop_database(name)
        create_database(name, options)
      end

      # Create a new MySQL database with optional <tt>:charset</tt> and <tt>:collation</tt>.
      # Charset defaults to utf8.
      #
      # Example:
      #   create_database 'charset_test', :charset => 'latin1', :collation => 'latin1_bin'
      #   create_database 'matt_development'
      #   create_database 'matt_development', :charset => :big5
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
      #   drop_database 'sebastian_development'
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

      def tables(name = nil, database = nil) #:nodoc:
        result = execute(["SHOW TABLES", database].compact.join(' IN '), 'SCHEMA')
        tables = result.collect { |field| field[0] }
        result.free
        tables
      end

      def table_exists?(name)
        return true if super

        name          = name.to_s
        schema, table = name.split('.', 2)

        unless table # A table was provided without a schema
          table  = schema
          schema = nil
        end

        tables(nil, schema).include? table
      end

      def drop_table(table_name, options = {})
        super(table_name, options)
      end

      # Returns an array of indexes for the given table.
      def indexes(table_name, name = nil)#:nodoc:
        indexes = []
        current_index = nil
        result = execute("SHOW KEYS FROM #{quote_table_name(table_name)}", name)
        result.each do |row|
          if current_index != row[2]
            next if row[2] == "PRIMARY" # skip the primary key
            current_index = row[2]
            indexes << IndexDefinition.new(row[0], row[2], row[1] == "0", [], [])
          end

          indexes.last.columns << row[4]
          indexes.last.lengths << row[7]
        end
        result.free
        indexes
      end

      # Returns an array of +MysqlColumn+ objects for the table specified by +table_name+.
      def columns(table_name, name = nil)#:nodoc:
        sql = "SHOW FIELDS FROM #{quote_table_name(table_name)}"
        result = execute(sql, 'SCHEMA')
        columns = result.collect { |field| MysqlColumn.new(field[0], field[4], field[1], field[2] == "YES") }
        result.free
        columns
      end

      def create_table(table_name, options = {}) #:nodoc:
        super(table_name, options.reverse_merge(:options => "ENGINE=InnoDB"))
      end

      # Renames a table.
      #
      # Example:
      #   rename_table('octopuses', 'octopi')
      def rename_table(table_name, new_name)
        execute "RENAME TABLE #{quote_table_name(table_name)} TO #{quote_table_name(new_name)}"
      end

      def bulk_change_table(table_name, operations) #:nodoc:
        sqls = operations.map do |command, args|
          table, arguments = args.shift, args
          method = :"#{command}_sql"

          if respond_to?(method)
            send(method, table, *arguments)
          else
            raise "Unknown method called : #{method}(#{arguments.inspect})"
          end
        end.flatten.join(", ")

        execute("ALTER TABLE #{quote_table_name(table_name)} #{sqls}")
      end

      def add_column(table_name, column_name, type, options = {})
        execute("ALTER TABLE #{quote_table_name(table_name)} #{add_column_sql(table_name, column_name, type, options)}")
      end

      def change_column_default(table_name, column_name, default) #:nodoc:
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
      end

      # Maps logical Rails types to MySQL-specific data types.
      def type_to_sql(type, limit = nil, precision = nil, scale = nil)
        return super unless type.to_s == 'integer'

        case limit
        when 1; 'tinyint'
        when 2; 'smallint'
        when 3; 'mediumint'
        when nil, 4, 11; 'int(11)'  # compatibility with MySQL default
        when 5..8; 'bigint'
        else raise(ActiveRecordError, "No integer type has byte size #{limit}")
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
        variables = select_all("SHOW VARIABLES LIKE '#{name}'")
        variables.first['Value'] unless variables.empty?
      end

      # Returns a table's primary key and belonging sequence.
      def pk_and_sequence_for(table) #:nodoc:
        keys = []
        result = execute("SHOW INDEX FROM #{quote_table_name(table)} WHERE Key_name = 'PRIMARY'", 'SCHEMA')
        result.each_hash do |h|
          keys << h["Column_name"]
        end
        result.free
        keys.length == 1 ? [keys.first, nil] : nil
      end

      # Returns just a table's primary key
      def primary_key(table)
        pk_and_sequence = pk_and_sequence_for(table)
        pk_and_sequence && pk_and_sequence.first
      end

      def case_sensitive_equality_operator
        "= BINARY"
      end
      deprecate :case_sensitive_equality_operator

      def case_sensitive_modifier(node)
        Arel::Nodes::Bin.new(node)
      end

      def limited_update_conditions(where_sql, quoted_table_name, quoted_primary_key)
        where_sql
      end

      protected
        def quoted_columns_for_index(column_names, options = {})
          length = options[:length] if options.is_a?(Hash)

          case length
          when Hash
            column_names.map {|name| length[name] ? "#{quote_column_name(name)}(#{length[name]})" : quote_column_name(name) }
          when Fixnum
            column_names.map {|name| "#{quote_column_name(name)}(#{length})"}
          else
            column_names.map {|name| quote_column_name(name) }
          end
        end

        def translate_exception(exception, message)
          return super unless exception.respond_to?(:errno)

          case exception.errno
          when 1062
            RecordNotUnique.new(message, exception)
          when 1452
            InvalidForeignKey.new(message, exception)
          else
            super
          end
        end

        def add_column_sql(table_name, column_name, type, options = {})
          add_column_sql = "ADD #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
          add_column_options!(add_column_sql, options)
          add_column_position!(add_column_sql, options)
          add_column_sql
        end

        def remove_column_sql(table_name, *column_names)
          columns_for_remove(table_name, *column_names).map {|column_name| "DROP #{column_name}" }
        end
        alias :remove_columns_sql :remove_column

        def change_column_sql(table_name, column_name, type, options = {})
          column = column_for(table_name, column_name)

          unless options_include_default?(options)
            options[:default] = column.default
          end

          unless options.has_key?(:null)
            options[:null] = column.null
          end

          change_column_sql = "CHANGE #{quote_column_name(column_name)} #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
          add_column_options!(change_column_sql, options)
          add_column_position!(change_column_sql, options)
          change_column_sql
        end

        def rename_column_sql(table_name, column_name, new_column_name)
          options = {}

          if column = columns(table_name).find { |c| c.name == column_name.to_s }
            options[:default] = column.default
            options[:null] = column.null
          else
            raise ActiveRecordError, "No such column: #{table_name}.#{column_name}"
          end

          current_type = select_one("SHOW COLUMNS FROM #{quote_table_name(table_name)} LIKE '#{column_name}'")["Type"]
          rename_column_sql = "CHANGE #{quote_column_name(column_name)} #{quote_column_name(new_column_name)} #{current_type}"
          add_column_options!(rename_column_sql, options)
          rename_column_sql
        end

        def add_index_sql(table_name, column_name, options = {})
          index_name, index_type, index_columns = add_index_options(table_name, column_name, options)
          "ADD #{index_type} INDEX #{index_name} (#{index_columns})"
        end

        def remove_index_sql(table_name, options = {})
          index_name = index_name_for_remove(table_name, options)
          "DROP INDEX #{index_name}"
        end

        def add_timestamps_sql(table_name)
          [add_column_sql(table_name, :created_at, :datetime), add_column_sql(table_name, :updated_at, :datetime)]
        end

        def remove_timestamps_sql(table_name)
          [remove_column_sql(table_name, :updated_at), remove_column_sql(table_name, :created_at)]
        end

      private
      def exec_stmt(sql, name, binds)
        cache = {}
        if binds.empty?
          stmt = @connection.prepare(sql)
        else
          cache = @statements[sql] ||= {
            :stmt => @connection.prepare(sql)
          }
          stmt = cache[:stmt]
        end


        begin
          stmt.execute(*binds.map { |col, val| type_cast(val, col) })
        rescue Mysql::Error => e
          # Older versions of MySQL leave the prepared statement in a bad
          # place when an error occurs.  To support older mysql versions, we
          # need to close the statement and delete the statement from the
          # cache.
          stmt.close
          @statements.delete sql
          raise e
        end

        cols = nil
        if metadata = stmt.result_metadata
          cols = cache[:cols] ||= metadata.fetch_fields.map { |field|
            field.name
          }
        end

        result = yield [cols, stmt]

        stmt.result_metadata.free if cols
        stmt.free_result
        stmt.close if binds.empty?

        result
      end

        def connect
          encoding = @config[:encoding]
          if encoding
            @connection.options(Mysql::SET_CHARSET_NAME, encoding) rescue nil
          end

          if @config[:sslca] || @config[:sslkey]
            @connection.ssl_set(@config[:sslkey], @config[:sslcert], @config[:sslca], @config[:sslcapath], @config[:sslcipher])
          end

          @connection.options(Mysql::OPT_CONNECT_TIMEOUT, @config[:connect_timeout]) if @config[:connect_timeout]
          @connection.options(Mysql::OPT_READ_TIMEOUT, @config[:read_timeout]) if @config[:read_timeout]
          @connection.options(Mysql::OPT_WRITE_TIMEOUT, @config[:write_timeout]) if @config[:write_timeout]

          @connection.real_connect(*@connection_options)

          # reconnect must be set after real_connect is called, because real_connect sets it to false internally
          @connection.reconnect = !!@config[:reconnect] if @connection.respond_to?(:reconnect=)

          configure_connection
        end

        def configure_connection
          encoding = @config[:encoding]
          execute("SET NAMES '#{encoding}'", :skip_logging) if encoding

          # By default, MySQL 'where id is null' selects the last inserted id.
          # Turn this off. http://dev.rubyonrails.org/ticket/6778
          execute("SET SQL_AUTO_IS_NULL=0", :skip_logging)
        end

        def select(sql, name = nil, binds = [])
          @connection.query_with_result = true
          rows = exec_query(sql, name, binds).to_a
          @connection.more_results && @connection.next_result    # invoking stored procedures with CLIENT_MULTI_RESULTS requires this to tidy up else connection will be dropped
          rows
        end

        def supports_views?
          version[0] >= 5
        end

        # Returns the version of the connected MySQL server.
        def version
          @version ||= @connection.server_info.scan(/^(\d+)\.(\d+)\.(\d+)/).flatten.map { |v| v.to_i }
        end

        def column_for(table_name, column_name)
          unless column = columns(table_name).find { |c| c.name == column_name.to_s }
            raise "No such column: #{table_name}.#{column_name}"
          end
          column
        end
    end
  end
end
