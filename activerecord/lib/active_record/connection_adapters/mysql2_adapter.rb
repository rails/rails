# encoding: utf-8

gem 'mysql2', '~> 0.3.6'
require 'mysql2'

module ActiveRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects.
    def self.mysql2_connection(config)
      config[:username] = 'root' if config[:username].nil?

      if Mysql2::Client.const_defined? :FOUND_ROWS
        config[:flags] = Mysql2::Client::FOUND_ROWS
      end

      client = Mysql2::Client.new(config.symbolize_keys)
      options = [config[:host], config[:username], config[:password], config[:database], config[:port], config[:socket], 0]
      ConnectionAdapters::Mysql2Adapter.new(client, logger, options, config)
    end
  end

  module ConnectionAdapters
    class Mysql2IndexDefinition < Struct.new(:table, :name, :unique, :columns, :lengths) #:nodoc:
    end

    class Mysql2Column < Column
      BOOL = "tinyint(1)"
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
          return :boolean if Mysql2Adapter.emulate_booleans && field_type.downcase.index(BOOL)

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

    class Mysql2Adapter < AbstractAdapter
      cattr_accessor :emulate_booleans
      self.emulate_booleans = true

      ADAPTER_NAME = 'Mysql2'
      PRIMARY = "PRIMARY"

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

      def initialize(connection, logger, connection_options, config)
        super(connection, logger)
        @connection_options, @config = connection_options, config
        @quoted_column_names, @quoted_table_names = {}, {}
        configure_connection
      end

      def self.visitor_for(pool) # :nodoc:
        Arel::Visitors::MySQL.new(pool)
      end

      def adapter_name
        ADAPTER_NAME
      end

      # Returns true, since this connection adapter supports migrations.
      def supports_migrations?
        true
      end

      def supports_primary_key?
        true
      end

      # Returns true, since this connection adapter supports savepoints.
      def supports_savepoints?
        true
      end

      def native_database_types
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

      def quote_column_name(name) #:nodoc:
        @quoted_column_names[name] ||= "`#{name.to_s.gsub('`', '``')}`"
      end

      def quote_table_name(name) #:nodoc:
        @quoted_table_names[name] ||= quote_column_name(name).gsub('.', '`.`')
      end

      def quote_string(string)
        @connection.escape(string)
      end

      def quoted_true
        QUOTED_TRUE
      end

      def quoted_false
        QUOTED_FALSE
      end

      def substitute_at(column, index)
        Arel.sql "\0"
      end

      # REFERENTIAL INTEGRITY ====================================

      def disable_referential_integrity(&block) #:nodoc:
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
        return false unless @connection
        @connection.ping
      end

      def reconnect!
        disconnect!
        connect
      end

      # this is set to true in 2.3, but we don't want it to be
      def requires_reloading?
        false
      end

      # Disconnects from the database if already connected.
      # Otherwise, this method does nothing.
      def disconnect!
        unless @connection.nil?
          @connection.close
          @connection = nil
        end
      end

      def reset!
        disconnect!
        connect
      end

      # DATABASE STATEMENTS ======================================

      # FIXME: re-enable the following once a "better" query_cache solution is in core
      #
      # The overrides below perform much better than the originals in AbstractAdapter
      # because we're able to take advantage of mysql2's lazy-loading capabilities
      #
      # # Returns a record hash with the column names as keys and column values
      # # as values.
      # def select_one(sql, name = nil)
      #   result = execute(sql, name)
      #   result.each(:as => :hash) do |r|
      #     return r
      #   end
      # end
      #
      # # Returns a single value from a record
      # def select_value(sql, name = nil)
      #   result = execute(sql, name)
      #   if first = result.first
      #     first.first
      #   end
      # end
      #
      # # Returns an array of the values of the first column in a select:
      # #   select_values("SELECT id FROM companies LIMIT 3") => [1,2,3]
      # def select_values(sql, name = nil)
      #   execute(sql, name).map { |row| row.first }
      # end

      # Returns an array of arrays containing the field values.
      # Order is the same as that returned by +columns+.
      def select_rows(sql, name = nil)
        execute(sql, name).to_a
      end

      # Executes the SQL statement in the context of this connection.
      def execute(sql, name = nil)
        # make sure we carry over any changes to ActiveRecord::Base.default_timezone that have been
        # made since we established the connection
        @connection.query_options[:database_timezone] = ActiveRecord::Base.default_timezone
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

      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        super
        id_value || @connection.last_id
      end
      alias :create :insert_sql

      def exec_insert(sql, name, binds)
        binds = binds.dup

        # Pretend to support bind parameters
        execute sql.gsub("\0") { quote(*binds.shift.reverse) }, name
      end

      def exec_delete(sql, name, binds)
        binds = binds.dup

        # Pretend to support bind parameters
        execute sql.gsub("\0") { quote(*binds.shift.reverse) }, name
        @connection.affected_rows
      end
      alias :exec_update :exec_delete

      def last_inserted_id(result)
        @connection.last_id
      end

      def update_sql(sql, name = nil)
        super
        @connection.affected_rows
      end

      def begin_db_transaction
        execute "BEGIN"
      rescue Exception
        # Transactions aren't supported
      end

      def commit_db_transaction
        execute "COMMIT"
      rescue Exception
        # Transactions aren't supported
      end

      def rollback_db_transaction
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

      def add_limit_offset!(sql, options)
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

      # SCHEMA STATEMENTS ========================================

      def structure_dump
        if supports_views?
          sql = "SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'"
        else
          sql = "SHOW TABLES"
        end

        select_all(sql).inject("") do |structure, table|
          table.delete('Table_type')
          structure += select_one("SHOW CREATE TABLE #{quote_table_name(table.to_a.first.last)}")["Create Table"] + ";\n\n"
        end
      end

      # Drops the database specified on the +name+ attribute
      # and creates it again using the provided +options+.
      def recreate_database(name, options = {})
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

      def tables(name = nil, database = nil) #:nodoc:
        sql = ["SHOW TABLES", database].compact.join(' IN ')
        execute(sql, 'SCHEMA').collect do |field|
          field.first
        end
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
      def indexes(table_name, name = nil)
        indexes = []
        current_index = nil
        result = execute("SHOW KEYS FROM #{quote_table_name(table_name)}", 'SCHEMA')
        result.each(:symbolize_keys => true, :as => :hash) do |row|
          if current_index != row[:Key_name]
            next if row[:Key_name] == PRIMARY # skip the primary key
            current_index = row[:Key_name]
            indexes << Mysql2IndexDefinition.new(row[:Table], row[:Key_name], row[:Non_unique] == 0, [], [])
          end

          indexes.last.columns << row[:Column_name]
          indexes.last.lengths << row[:Sub_part]
        end
        indexes
      end

      # Returns an array of +Mysql2Column+ objects for the table specified by +table_name+.
      def columns(table_name, name = nil)
        sql = "SHOW FIELDS FROM #{quote_table_name(table_name)}"
        columns = []
        result = execute(sql, 'SCHEMA')
        result.each(:symbolize_keys => true, :as => :hash) { |field|
          columns << Mysql2Column.new(field[:Field], field[:Default], field[:Type], field[:Null] == "YES")
        }
        columns
      end

      def create_table(table_name, options = {})
        super(table_name, options.reverse_merge(:options => "ENGINE=InnoDB"))
      end

      # Renames a table.
      #
      # Example:
      #   rename_table('octopuses', 'octopi')
      def rename_table(table_name, new_name)
        execute "RENAME TABLE #{quote_table_name(table_name)} TO #{quote_table_name(new_name)}"
      end

      def add_column(table_name, column_name, type, options = {})
        add_column_sql = "ALTER TABLE #{quote_table_name(table_name)} ADD #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        add_column_options!(add_column_sql, options)
        add_column_position!(add_column_sql, options)
        execute(add_column_sql)
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

      def change_column(table_name, column_name, type, options = {})
        column = column_for(table_name, column_name)

        unless options_include_default?(options)
          options[:default] = column.default
        end

        unless options.has_key?(:null)
          options[:null] = column.null
        end

        change_column_sql = "ALTER TABLE #{quote_table_name(table_name)} CHANGE #{quote_column_name(column_name)} #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        add_column_options!(change_column_sql, options)
        add_column_position!(change_column_sql, options)
        execute(change_column_sql)
      end

      def rename_column(table_name, column_name, new_column_name)
        options = {}
        if column = columns(table_name).find { |c| c.name == column_name.to_s }
          options[:default] = column.default
          options[:null] = column.null
        else
          raise ActiveRecordError, "No such column: #{table_name}.#{column_name}"
        end
        current_type = select_one("SHOW COLUMNS FROM #{quote_table_name(table_name)} LIKE '#{column_name}'")["Type"]
        rename_column_sql = "ALTER TABLE #{quote_table_name(table_name)} CHANGE #{quote_column_name(column_name)} #{quote_column_name(new_column_name)} #{current_type}"
        add_column_options!(rename_column_sql, options)
        execute(rename_column_sql)
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

      # SHOW VARIABLES LIKE 'name'.
      def show_variable(name)
        variables = select_all("SHOW VARIABLES LIKE '#{name}'")
        variables.first['Value'] unless variables.empty?
      end

      # Returns a table's primary key and belonging sequence.
      def pk_and_sequence_for(table)
        keys = []
        result = execute("SHOW INDEX FROM #{quote_table_name(table)} WHERE Key_name = 'PRIMARY'", 'SCHEMA')
        result.each(:symbolize_keys => true, :as => :hash) do |row|
          keys << row[:Column_name]
        end
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

      protected
        def quoted_columns_for_index(column_names, options = {})
          length = options[:length] if options.is_a?(Hash)

          quoted_column_names = case length
          when Hash
            column_names.map {|name| length[name] ? "#{quote_column_name(name)}(#{length[name]})" : quote_column_name(name) }
          when Fixnum
            column_names.map {|name| "#{quote_column_name(name)}(#{length})"}
          else
            column_names.map {|name| quote_column_name(name) }
          end
        end

        def translate_exception(exception, message)
          return super unless exception.respond_to?(:error_number)

          case exception.error_number
          when 1062
            RecordNotUnique.new(message, exception)
          when 1452
            InvalidForeignKey.new(message, exception)
          else
            super
          end
        end

      private
        def connect
          @connection = Mysql2::Client.new(@config)
          configure_connection
        end

        def configure_connection
          @connection.query_options.merge!(:as => :array)

          # By default, MySQL 'where id is null' selects the last inserted id.
          # Turn this off. http://dev.rubyonrails.org/ticket/6778
          variable_assignments = ['SQL_AUTO_IS_NULL=0']
          encoding = @config[:encoding]

          # make sure we set the encoding
          variable_assignments << "NAMES '#{encoding}'" if encoding

          # increase timeout so mysql server doesn't disconnect us
          wait_timeout = @config[:wait_timeout]
          wait_timeout = 2592000 unless wait_timeout.is_a?(Fixnum)
          variable_assignments << "@@wait_timeout = #{wait_timeout}"

          execute("SET #{variable_assignments.join(', ')}", :skip_logging)
        end

        # Returns an array of record hashes with the column names as keys and
        # column values as values.
        def select(sql, name = nil, binds = [])
          binds = binds.dup
          exec_query(sql.gsub("\0") { quote(*binds.shift.reverse) }, name).to_a
        end

        def exec_query(sql, name = 'SQL', binds = [])
          @connection.query_options[:database_timezone] = ActiveRecord::Base.default_timezone

          log(sql, name, binds) do
            begin
              result = @connection.query(sql)
            rescue ActiveRecord::StatementInvalid => exception
              if exception.message.split(":").first =~ /Packets out of order/
                raise ActiveRecord::StatementInvalid, "'Packets out of order' error was received from the database. Please update your mysql bindings (gem install mysql) and read http://dev.mysql.com/doc/mysql/en/password-hashing.html for more information.  If you're on Windows, use the Instant Rails installer to get the updated mysql bindings."
              else
                raise
              end
            end

            ActiveRecord::Result.new(result.fields, result.to_a)
          end
        end

        def supports_views?
          version[0] >= 5
        end

        def version
          @version ||= @connection.info[:version].scan(/^(\d+)\.(\d+)\.(\d+)/).flatten.map { |v| v.to_i }
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
