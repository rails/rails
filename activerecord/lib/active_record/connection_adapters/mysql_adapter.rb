require 'active_record/connection_adapters/abstract_mysql_adapter'
require 'active_record/connection_adapters/statement_pool'
require 'active_support/core_ext/hash/keys'

gem 'mysql', '~> 2.9'
require 'mysql'

class Mysql
  class Time
    def to_date
      Date.new(year, month, day)
    end
  end
  class Stmt; include Enumerable end
  class Result; include Enumerable end
end

module ActiveRecord
  module ConnectionHandling # :nodoc:
    # Establishes a connection to the database that's used by all Active Record objects.
    def mysql_connection(config)
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
    rescue Mysql::Error => error
      if error.message.include?("Unknown database")
        raise ActiveRecord::NoDatabaseError.new(error.message, error)
      else
        raise
      end
    end
  end

  module ConnectionAdapters
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
    # * <tt>:strict</tt> - Defaults to true. Enable STRICT_ALL_TABLES. (See MySQL documentation: http://dev.mysql.com/doc/refman/5.0/en/sql-mode.html)
    # * <tt>:variables</tt> - (Optional) A hash session variables to send as <tt>SET @@SESSION.key = value</tt> on each database connection. Use the value +:default+ to set a variable to its DEFAULT value. (See MySQL documentation: http://dev.mysql.com/doc/refman/5.0/en/set-statement.html).
    # * <tt>:sslca</tt> - Necessary to use MySQL with an SSL connection.
    # * <tt>:sslkey</tt> - Necessary to use MySQL with an SSL connection.
    # * <tt>:sslcert</tt> - Necessary to use MySQL with an SSL connection.
    # * <tt>:sslcapath</tt> - Necessary to use MySQL with an SSL connection.
    # * <tt>:sslcipher</tt> - Necessary to use MySQL with an SSL connection.
    #
    class MysqlAdapter < AbstractMysqlAdapter
      ADAPTER_NAME = 'MySQL'.freeze

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
          cache.each_value do |hash|
            hash[:stmt].close
          end
          cache.clear
        end

        private
        def cache
          @cache[Process.pid]
        end
      end

      def initialize(connection, logger, connection_options, config)
        super
        @statements = StatementPool.new(@connection,
                                        self.class.type_cast_config_to_integer(config.fetch(:statement_limit) { 1000 }))
        @client_encoding = nil
        connect
      end

      # Returns true, since this connection adapter supports prepared statement
      # caching.
      def supports_statement_cache?
        true
      end

      # HELPER METHODS ===========================================

      def each_hash(result) # :nodoc:
        if block_given?
          result.each_hash do |row|
            row.symbolize_keys!
            yield row
          end
        else
          to_enum(:each_hash, result)
        end
      end

      def error_number(exception) # :nodoc:
        exception.errno if exception.respond_to?(:errno)
      end

      # QUOTING ==================================================

      def quote_string(string) #:nodoc:
        @connection.quote(string)
      end

      #--
      # CONNECTION MANAGEMENT ====================================
      #++

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
        super
        disconnect!
        connect
      end

      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        super
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

      #--
      # DATABASE STATEMENTS ======================================
      #++

      def select_rows(sql, name = nil, binds = [])
        @connection.query_with_result = true
        rows = exec_query(sql, name, binds).rows
        @connection.more_results && @connection.next_result    # invoking stored procedures with CLIENT_MULTI_RESULTS requires this to tidy up else connection will be dropped
        rows
      end

      # Clears the prepared statements cache.
      def clear_cache!
        super
        @statements.clear
      end

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

      # Get the client encoding for this database
      def client_encoding
        return @client_encoding if @client_encoding

        result = exec_query(
          "select @@character_set_client",
          'SCHEMA')
        @client_encoding = ENCODINGS[result.rows.last.last]
      end

      def exec_query(sql, name = 'SQL', binds = [])
        if without_prepared_statement?(binds)
          result_set, affected_rows = exec_without_stmt(sql, name)
        else
          result_set, affected_rows = exec_stmt(sql, name, binds)
        end

        yield affected_rows if block_given?

        result_set
      end

      def last_inserted_id(result)
        @connection.insert_id
      end

      module Fields # :nodoc:
        class DateTime < Type::DateTime # :nodoc:
          def cast_value(value)
            if Mysql::Time === value
              new_time(
                value.year,
                value.month,
                value.day,
                value.hour,
                value.minute,
                value.second,
                value.second_part)
            else
              super
            end
          end

          def has_precision?
            precision || 0
          end
        end

        class Time < Type::Time # :nodoc:
          def cast_value(value)
            if Mysql::Time === value
              new_time(
                2000,
                01,
                01,
                value.hour,
                value.minute,
                value.second,
                value.second_part)
            else
              super
            end
          end
        end

        class << self
          TYPES = Type::HashLookupTypeMap.new # :nodoc:

          delegate :register_type, :alias_type, to: :TYPES

          def find_type(field)
            if field.type == Mysql::Field::TYPE_TINY && field.length > 1
              TYPES.lookup(Mysql::Field::TYPE_LONG)
            else
              TYPES.lookup(field.type)
            end
          end
        end

        register_type Mysql::Field::TYPE_TINY,    Type::Boolean.new
        register_type Mysql::Field::TYPE_LONG,    Type::Integer.new
        alias_type Mysql::Field::TYPE_LONGLONG,   Mysql::Field::TYPE_LONG
        alias_type Mysql::Field::TYPE_NEWDECIMAL, Mysql::Field::TYPE_LONG

        register_type Mysql::Field::TYPE_DATE, Type::Date.new
        register_type Mysql::Field::TYPE_DATETIME, Fields::DateTime.new
        register_type Mysql::Field::TYPE_TIME, Fields::Time.new
        register_type Mysql::Field::TYPE_FLOAT, Type::Float.new
      end

      def initialize_type_map(m) # :nodoc:
        super
        m.register_type %r(time)i,     Fields::Time.new
        m.register_type(%r(datetime)i) do |sql_type|
          precision = extract_precision(sql_type)
          Fields::DateTime.new(precision: precision)
        end
      end

      def exec_without_stmt(sql, name = 'SQL') # :nodoc:
        # Some queries, like SHOW CREATE TABLE don't work through the prepared
        # statement API. For those queries, we need to use this method. :'(
        log(sql, name) do
          result = @connection.query(sql)
          affected_rows = @connection.affected_rows

          if result
            types = {}
            fields = []
            result.fetch_fields.each { |field|
              field_name = field.name
              fields << field_name

              if field.decimals > 0
                types[field_name] = Type::Decimal.new
              else
                types[field_name] = Fields.find_type field
              end
            }

            result_set = ActiveRecord::Result.new(fields, result.to_a, types)
            result.free
          else
            result_set = ActiveRecord::Result.new([], [])
          end

          [result_set, affected_rows]
        end
      end

      def execute_and_free(sql, name = nil) # :nodoc:
        result = execute(sql, name)
        ret = yield result
        result.free
        ret
      end

      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
        super sql, name
        id_value || @connection.insert_id
      end
      alias :create :insert_sql

      def exec_delete(sql, name, binds) # :nodoc:
        affected_rows = 0

        exec_query(sql, name, binds) do |n|
          affected_rows = n
        end

        affected_rows
      end
      alias :exec_update :exec_delete

      def begin_db_transaction #:nodoc:
        exec_query "BEGIN"
      end

      private

      def exec_stmt(sql, name, binds)
        cache = {}
        type_casted_binds = binds.map { |col, val|
          [col, type_cast(val, col)]
        }

        log(sql, name, type_casted_binds) do
          if binds.empty?
            stmt = @connection.prepare(sql)
          else
            cache = @statements[sql] ||= {
              :stmt => @connection.prepare(sql)
            }
            stmt = cache[:stmt]
          end

          begin
            stmt.execute(*type_casted_binds.map { |_, val| val })
          rescue Mysql::Error => e
            # Older versions of MySQL leave the prepared statement in a bad
            # place when an error occurs. To support older MySQL versions, we
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
            metadata.free
          end

          result_set = ActiveRecord::Result.new(cols, stmt.to_a) if cols
          affected_rows = stmt.affected_rows

          stmt.free_result
          stmt.close if binds.empty?

          [result_set, affected_rows]
        end
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

      # Many Rails applications monkey-patch a replacement of the configure_connection method
      # and don't call 'super', so leave this here even though it looks superfluous.
      def configure_connection
        super
      end

      def select(sql, name = nil, binds = [])
        @connection.query_with_result = true
        rows = super
        @connection.more_results && @connection.next_result    # invoking stored procedures with CLIENT_MULTI_RESULTS requires this to tidy up else connection will be dropped
        rows
      end

      # Returns the full version of the connected MySQL server.
      def full_version
        @full_version ||= @connection.server_info
      end

      def set_field_encoding field_name
        field_name.force_encoding(client_encoding)
        if internal_enc = Encoding.default_internal
          field_name = field_name.encode!(internal_enc)
        end
        field_name
      end
    end
  end
end
