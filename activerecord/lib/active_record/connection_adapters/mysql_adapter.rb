require 'active_record/connection_adapters/abstract_adapter'
require 'set'

module MysqlCompat #:nodoc:
  # add all_hashes method to standard mysql-c bindings or pure ruby version
  def self.define_all_hashes_method!
    raise 'Mysql not loaded' unless defined?(::Mysql)

    target = defined?(Mysql::Result) ? Mysql::Result : MysqlRes
    return if target.instance_methods.include?('all_hashes')

    # Ruby driver has a version string and returns null values in each_hash
    # C driver >= 2.7 returns null values in each_hash
    if Mysql.const_defined?(:VERSION) && (Mysql::VERSION.is_a?(String) || Mysql::VERSION >= 20700)
      target.class_eval <<-'end_eval'
      def all_hashes
        rows = []
        each_hash { |row| rows << row }
        rows
      end
      end_eval

    # adapters before 2.7 don't have a version constant
    # and don't return null values in each_hash
    else
      target.class_eval <<-'end_eval'
      def all_hashes
        rows = []
        all_fields = fetch_fields.inject({}) { |fields, f| fields[f.name] = nil; fields }
        each_hash { |row| rows << all_fields.dup.update(row) }
        rows
      end
      end_eval
    end

    unless target.instance_methods.include?('all_hashes') ||
           target.instance_methods.include?(:all_hashes)
      raise "Failed to defined #{target.name}#all_hashes method. Mysql::VERSION = #{Mysql::VERSION.inspect}"
    end
  end
end

module ActiveRecord
  class Base
    def self.require_mysql
      # Include the MySQL driver if one hasn't already been loaded
      unless defined? Mysql
        begin
          require_library_or_gem 'mysql'
        rescue LoadError => cannot_require_mysql
          # Use the bundled Ruby/MySQL driver if no driver is already in place
          begin
            ActiveRecord::Base.logger.info(
              "WARNING: You're using the Ruby-based MySQL library that ships with Rails. This library is not suited for production. " +
              "Please install the C-based MySQL library instead (gem install mysql)."
            ) if ActiveRecord::Base.logger

            require 'active_record/vendor/mysql'
          rescue LoadError
            raise cannot_require_mysql
          end
        end
      end

      # Define Mysql::Result.all_hashes
      MysqlCompat.define_all_hashes_method!
    end

    # Establishes a connection to the database that's used by all Active Record objects.
    def self.mysql_connection(config) # :nodoc:
      config = config.symbolize_keys
      host     = config[:host]
      port     = config[:port]
      socket   = config[:socket]
      username = config[:username] ? config[:username].to_s : 'root'
      password = config[:password].to_s

      if config.has_key?(:database)
        database = config[:database]
      else
        raise ArgumentError, "No database specified. Missing argument: database."
      end

      require_mysql
      mysql = Mysql.init
      mysql.ssl_set(config[:sslkey], config[:sslcert], config[:sslca], config[:sslcapath], config[:sslcipher]) if config[:sslkey]

      ConnectionAdapters::MysqlAdapter.new(mysql, logger, [host, username, password, database, port, socket], config)
    end
  end

  module ConnectionAdapters
    class MysqlColumn < Column #:nodoc:
      TYPES_DISALLOWING_DEFAULT = Set.new([:binary, :text])
      TYPES_ALLOWING_EMPTY_STRING_DEFAULT = Set.new([:string])

      def initialize(name, default, sql_type = nil, null = true)
        @original_default = default
        super
        @default = nil if no_default_allowed? || missing_default_forged_as_empty_string?
        @default = '' if @original_default == '' && no_default_allowed?
      end

      private
        def simplified_type(field_type)
          return :boolean if MysqlAdapter.emulate_booleans && field_type.downcase.index("tinyint(1)")
          return :string  if field_type =~ /enum/i
          super
        end

        # MySQL misreports NOT NULL column default when none is given.
        # We can't detect this for columns which may have a legitimate ''
        # default (string) but we can for others (integer, datetime, boolean,
        # and the rest).
        #
        # Test whether the column has default '', is not null, and is not
        # a type allowing default ''.
        def missing_default_forged_as_empty_string?
          !null && @original_default == '' && !TYPES_ALLOWING_EMPTY_STRING_DEFAULT.include?(type)
        end

        # MySQL 5.0 does not allow text and binary columns to have defaults
        def no_default_allowed?
          TYPES_DISALLOWING_DEFAULT.include?(type)
        end
    end

    # The MySQL adapter will work with both Ruby/MySQL, which is a Ruby-based MySQL adapter that comes bundled with Active Record, and with
    # the faster C-based MySQL/Ruby adapter (available both as a gem and from http://www.tmtm.org/en/mysql/ruby/).
    #
    # Options:
    #
    # * <tt>:host</tt> -- Defaults to localhost
    # * <tt>:port</tt> -- Defaults to 3306
    # * <tt>:socket</tt> -- Defaults to /tmp/mysql.sock
    # * <tt>:username</tt> -- Defaults to root
    # * <tt>:password</tt> -- Defaults to nothing
    # * <tt>:database</tt> -- The name of the database. No default, must be provided.
    # * <tt>:encoding</tt> -- (Optional) Sets the client encoding by executing "SET NAMES <encoding>" after connection
    # * <tt>:sslkey</tt> -- Necessary to use MySQL with an SSL connection
    # * <tt>:sslcert</tt> -- Necessary to use MySQL with an SSL connection
    # * <tt>:sslcapath</tt> -- Necessary to use MySQL with an SSL connection
    # * <tt>:sslcipher</tt> -- Necessary to use MySQL with an SSL connection
    #
    # By default, the MysqlAdapter will consider all columns of type tinyint(1)
    # as boolean. If you wish to disable this emulation (which was the default
    # behavior in versions 0.13.1 and earlier) you can add the following line
    # to your environment.rb file:
    #
    #   ActiveRecord::ConnectionAdapters::MysqlAdapter.emulate_booleans = false
    class MysqlAdapter < AbstractAdapter
      @@emulate_booleans = true
      cattr_accessor :emulate_booleans

      LOST_CONNECTION_ERROR_MESSAGES = [
        "Server shutdown in progress",
        "Broken pipe",
        "Lost connection to MySQL server during query",
        "MySQL server has gone away"
      ]

      def initialize(connection, logger, connection_options, config)
        super(connection, logger)
        @connection_options, @config = connection_options, config

        connect
      end

      def adapter_name #:nodoc:
        'MySQL'
      end

      def supports_migrations? #:nodoc:
        true
      end

      def native_database_types #:nodoc:
        {
          :primary_key => "int(11) DEFAULT NULL auto_increment PRIMARY KEY",
          :string      => { :name => "varchar", :limit => 255 },
          :text        => { :name => "text" },
          :integer     => { :name => "int", :limit => 11 },
          :float       => { :name => "float" },
          :decimal     => { :name => "decimal" },
          :datetime    => { :name => "datetime" },
          :timestamp   => { :name => "datetime" },
          :time        => { :name => "time" },
          :date        => { :name => "date" },
          :binary      => { :name => "blob" },
          :boolean     => { :name => "tinyint", :limit => 1 }
        }
      end


      # QUOTING ==================================================

      def quote(value, column = nil)
        if value.kind_of?(String) && column && column.type == :binary && column.class.respond_to?(:string_to_binary)
          s = column.class.string_to_binary(value).unpack("H*")[0]
          "x'#{s}'"
        elsif value.kind_of?(BigDecimal)
          "'#{value.to_s("F")}'"
        else
          super
        end
      end

      def quote_column_name(name) #:nodoc:
        "`#{name}`"
      end

      def quote_string(string) #:nodoc:
        @connection.quote(string)
      end

      def quoted_true
        "1"
      end

      def quoted_false
        "0"
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
        connect
      end

      def disconnect!
        @connection.close rescue nil
      end


      # DATABASE STATEMENTS ======================================

      def select_rows(sql, name = nil)
        @connection.query_with_result = true
        result = execute(sql, name)
        rows = []
        result.each { |row| rows << row }
        result.free
        rows
      end

      def execute(sql, name = nil) #:nodoc:
        log(sql, name) { @connection.query(sql) }
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

      def update_sql(sql, name = nil) #:nodoc:
        super
        @connection.affected_rows
      end

      def begin_db_transaction #:nodoc:
        execute "BEGIN"
      rescue Exception
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


      def add_limit_offset!(sql, options) #:nodoc:
        if limit = options[:limit]
          unless offset = options[:offset]
            sql << " LIMIT #{limit}"
          else
            sql << " LIMIT #{offset}, #{limit}"
          end
        end
      end


      # SCHEMA STATEMENTS ========================================

      def structure_dump #:nodoc:
        if supports_views?
          sql = "SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'"
        else
          sql = "SHOW TABLES"
        end

        select_all(sql).inject("") do |structure, table|
          table.delete('Table_type')
          structure += select_one("SHOW CREATE TABLE #{table.to_a.first.last}")["Create Table"] + ";\n\n"
        end
      end

      def recreate_database(name) #:nodoc:
        drop_database(name)
        create_database(name)
      end

      # Create a new MySQL database with optional :charset and :collation.
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

      def tables(name = nil) #:nodoc:
        tables = []
        execute("SHOW TABLES", name).each { |field| tables << field[0] }
        tables
      end

      def indexes(table_name, name = nil)#:nodoc:
        indexes = []
        current_index = nil
        execute("SHOW KEYS FROM #{table_name}", name).each do |row|
          if current_index != row[2]
            next if row[2] == "PRIMARY" # skip the primary key
            current_index = row[2]
            indexes << IndexDefinition.new(row[0], row[2], row[1] == "0", [])
          end

          indexes.last.columns << row[4]
        end
        indexes
      end

      def columns(table_name, name = nil)#:nodoc:
        sql = "SHOW FIELDS FROM #{table_name}"
        columns = []
        execute(sql, name).each { |field| columns << MysqlColumn.new(field[0], field[4], field[1], field[2] == "YES") }
        columns
      end

      def create_table(name, options = {}) #:nodoc:
        super(name, {:options => "ENGINE=InnoDB"}.merge(options))
      end

      def rename_table(name, new_name)
        execute "RENAME TABLE #{name} TO #{new_name}"
      end

      def change_column_default(table_name, column_name, default) #:nodoc:
        current_type = select_one("SHOW COLUMNS FROM #{table_name} LIKE '#{column_name}'")["Type"]

        execute("ALTER TABLE #{table_name} CHANGE #{quote_column_name(column_name)} #{quote_column_name(column_name)} #{current_type} DEFAULT #{quote(default)}")
      end

      def change_column(table_name, column_name, type, options = {}) #:nodoc:
        unless options_include_default?(options)
          if result = select_one("SHOW COLUMNS FROM #{table_name} LIKE '#{column_name}'")
            options[:default] = result['Default']
          else
            raise "No such column: #{table_name}.#{column_name}"
          end
        end

        change_column_sql = "ALTER TABLE #{table_name} CHANGE #{quote_column_name(column_name)} #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        add_column_options!(change_column_sql, options)
        execute(change_column_sql)
      end

      def rename_column(table_name, column_name, new_column_name) #:nodoc:
        current_type = select_one("SHOW COLUMNS FROM #{table_name} LIKE '#{column_name}'")["Type"]
        execute "ALTER TABLE #{table_name} CHANGE #{quote_column_name(column_name)} #{quote_column_name(new_column_name)} #{current_type}"
      end


      # SHOW VARIABLES LIKE 'name'
      def show_variable(name)
        variables = select_all("SHOW VARIABLES LIKE '#{name}'")
        variables.first['Value'] unless variables.empty?
      end

      private
        def connect
          encoding = @config[:encoding]
          if encoding
            @connection.options(Mysql::SET_CHARSET_NAME, encoding) rescue nil
          end
          @connection.ssl_set(@config[:sslkey], @config[:sslcert], @config[:sslca], @config[:sslcapath], @config[:sslcipher]) if @config[:sslkey]
          @connection.real_connect(*@connection_options)
          execute("SET NAMES '#{encoding}'") if encoding

          # By default, MySQL 'where id is null' selects the last inserted id.
          # Turn this off. http://dev.rubyonrails.org/ticket/6778
          execute("SET SQL_AUTO_IS_NULL=0")
        end

        def select(sql, name = nil)
          @connection.query_with_result = true
          result = execute(sql, name)
          rows = result.all_hashes
          result.free
          rows
        end

        def supports_views?
          version[0] >= 5
        end

        def version
          @version ||= @connection.server_info.scan(/^(\d+)\.(\d+)\.(\d+)/).flatten.map { |v| v.to_i }
        end
    end
  end
end
