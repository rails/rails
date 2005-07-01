require 'active_record/connection_adapters/abstract_adapter'
require 'parsedate'
 
module ActiveRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects.
    def self.mysql_connection(config) # :nodoc:
      unless self.class.const_defined?(:Mysql)
        begin
          # Only include the MySQL driver if one hasn't already been loaded
          require_library_or_gem 'mysql'
        rescue LoadError => cannot_require_mysql
          # Only use the supplied backup Ruby/MySQL driver if no driver is already in place
          begin 
            require 'active_record/vendor/mysql'
            require 'active_record/vendor/mysql411'
          rescue LoadError
            raise cannot_require_mysql
          end
        end
      end
 
      symbolize_strings_in_hash(config)
 
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
 
      mysql = Mysql.init
      mysql.ssl_set(config[:sslkey], config[:sslcert], config[:sslca], config[:sslcapath], config[:sslcipher]) if config[:sslkey]
      ConnectionAdapters::MysqlAdapter.new(mysql.real_connect(host, username, password, database, port, socket), logger, [host, username, password, database, port, socket])
    end
  end
 
  module ConnectionAdapters
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
    # * <tt>:sslkey</tt> -- Necessary to use MySQL with an SSL connection
    # * <tt>:sslcert</tt> -- Necessary to use MySQL with an SSL connection
    # * <tt>:sslcapath</tt> -- Necessary to use MySQL with an SSL connection
    # * <tt>:sslcipher</tt> -- Necessary to use MySQL with an SSL connection
    class MysqlAdapter < AbstractAdapter
      LOST_CONNECTION_ERROR_MESSAGES = [ 
        "Server shutdown in progress",
        "Broken pipe", 
        "Lost connection to MySQL server during query", 
        "MySQL server has gone away"
      ]

      def native_database_types
        {
          :primary_key => "int(11) DEFAULT NULL auto_increment PRIMARY KEY",
          :string      => { :name => "varchar", :limit => 255 },
          :text        => { :name => "text" },
          :integer     => { :name => "int", :limit => 11 },
          :float       => { :name => "float" },
          :datetime    => { :name => "datetime" },
          :timestamp   => { :name => "datetime" },
          :time        => { :name => "datetime" },
          :date        => { :name => "date" },
          :binary      => { :name => "blob" },
          :boolean     => { :name => "tinyint", :limit => 1 }
        }
      end

      def initialize(connection, logger, connection_options=nil)
        super(connection, logger)
        @connection_options = connection_options
      end
 
      def adapter_name
        'MySQL'
      end


      def select_all(sql, name = nil)
        select(sql, name)
      end
 
      def select_one(sql, name = nil)
        result = select(sql, name)
        result.nil? ? nil : result.first
      end
 
      def columns(table_name, name = nil)
        sql = "SHOW FIELDS FROM #{table_name}" 
        columns = []
        execute(sql, name).each { |field| columns << Column.new(field[0], field[4], field[1]) }
        columns
      end
 
      def insert(sql, name = nil, pk = nil, id_value = nil)
        execute(sql, name = nil)
        return id_value || @connection.insert_id
      end
 
      def execute(sql, name = nil)
        begin
          return log(sql, name, @connection) { |connection| connection.query(sql) }
        rescue ActiveRecord::StatementInvalid => exception
          if LOST_CONNECTION_ERROR_MESSAGES.any? { |msg| exception.message.split(":").first =~ /^#{msg}/ }
            @connection.real_connect(*@connection_options)
            @logger.info("Retrying invalid statement with reopened connection") if @logger
            return log(sql, name, @connection) { |connection| connection.query(sql) }
          else
            raise
          end
        end
      end
 
      def update(sql, name = nil)
        execute(sql, name)
        @connection.affected_rows
      end
 
      alias_method :delete, :update
 
 
      def begin_db_transaction
        begin
          execute "BEGIN"
        rescue Exception
          # Transactions aren't supported
        end
      end
 
      def commit_db_transaction
        begin
          execute "COMMIT"
        rescue Exception
          # Transactions aren't supported
        end
      end
 
      def rollback_db_transaction
        begin
          execute "ROLLBACK"
        rescue Exception
          # Transactions aren't supported
        end
      end

 
      def quote_column_name(name)
        return "`#{name}`"
      end
 
      def quote_string(s)
        Mysql::quote(s)
      end


      def structure_dump
        select_all("SHOW TABLES").inject("") do |structure, table|
          structure += select_one("SHOW CREATE TABLE #{table.to_a.first.last}")["Create Table"] + ";\n\n"
        end
      end

      def add_limit_offset!(sql, options)
        return if options[:limit].nil?

        if options[:offset].blank?
          sql << " LIMIT #{options[:limit]}"
        else
          sql << " LIMIT #{options[:offset]}, #{options[:limit]}"
        end
      end

      def recreate_database(name)
        drop_database(name)
        create_database(name)
      end
 
      def drop_database(name)
        execute "DROP DATABASE IF EXISTS #{name}"
      end
 
      def create_database(name)
        execute "CREATE DATABASE #{name}"
      end

      
      def create_table(name)
        super(name, "ENGINE=InnoDB")
      end

      private
        def select(sql, name = nil)
          result = nil
          @connection.query_with_result = true
          result = execute(sql, name)
          rows = []
          all_fields_initialized = result.fetch_fields.inject({}) { |all_fields, f| all_fields[f.name] = nil; all_fields }
          result.each_hash { |row| rows << all_fields_initialized.dup.update(row) }
          rows
        end
    end
  end
end