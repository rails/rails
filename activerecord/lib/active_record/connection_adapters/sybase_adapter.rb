# sybase_adaptor.rb
# Author: John R. Sheets
# 
# 01 Mar 2006: Initial version.  Based on code from Will Sobel
#              (http://dev.rubyonrails.org/ticket/2030)
# 
# 17 Mar 2006: Added support for migrations; fixed issues with :boolean columns.
# 
# 13 Apr 2006: Improved column type support to properly handle dates and user-defined
#              types; fixed quoting of integer columns.
# 
# 05 Jan 2007: Updated for Rails 1.2 release:
#              restricted Fixtures#insert_fixtures monkeypatch to Sybase adapter;
#              removed SQL type precision from TEXT type to fix broken
#              ActiveRecordStore (jburks, #6878); refactored select() to use execute();
#              fixed leaked exception for no-op change_column(); removed verbose SQL dump
#              from columns(); added missing scale parameter in normalize_type().

require 'active_record/connection_adapters/abstract_adapter'

begin
require 'sybsql'

module ActiveRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects
    def self.sybase_connection(config) # :nodoc:
      config = config.symbolize_keys

      username = config[:username] ? config[:username].to_s : 'sa'
      password = config[:password] ? config[:password].to_s : ''

      if config.has_key?(:host)
        host = config[:host]
      else
        raise ArgumentError, "No database server name specified. Missing argument: host."
      end

      if config.has_key?(:database)
        database = config[:database]
      else
        raise ArgumentError, "No database specified. Missing argument: database."
      end

      ConnectionAdapters::SybaseAdapter.new(
        SybSQL.new({'S' => host, 'U' => username, 'P' => password},
          ConnectionAdapters::SybaseAdapterContext), database, config, logger)
    end
  end # class Base

  module ConnectionAdapters

    # ActiveRecord connection adapter for Sybase Open Client bindings
    # (see http://raa.ruby-lang.org/project/sybase-ctlib).
    #
    # Options:
    #
    # * <tt>:host</tt> -- The name of the database server. No default, must be provided.
    # * <tt>:database</tt> -- The name of the database. No default, must be provided.
    # * <tt>:username</tt>  -- Defaults to "sa".
    # * <tt>:password</tt>  -- Defaults to empty string.
    #
    # Usage Notes:
    #
    # * The sybase-ctlib bindings do not support the DATE SQL column type; use DATETIME instead.
    # * Table and column names are limited to 30 chars in Sybase 12.5
    # * :binary columns not yet supported
    # * :boolean columns use the BIT SQL type, which does not allow nulls or 
    #   indexes.  If a DEFAULT is not specified for ALTER TABLE commands, the
    #   column will be declared with DEFAULT 0 (false).
    #
    # Migrations:
    #
    # The Sybase adapter supports migrations, but for ALTER TABLE commands to
    # work, the database must have the database option 'select into' set to
    # 'true' with sp_dboption (see below).  The sp_helpdb command lists the current
    # options for all databases.
    #
    #   1> use mydb
    #   2> go
    #   1> master..sp_dboption mydb, "select into", true
    #   2> go
    #   1> checkpoint
    #   2> go
    class SybaseAdapter < AbstractAdapter # :nodoc:
      class ColumnWithIdentity < Column
        attr_reader :identity

        def initialize(name, default, sql_type = nil, nullable = nil, identity = nil, primary = nil)
          super(name, default, sql_type, nullable)
          @default, @identity, @primary = type_cast(default), identity, primary
        end

        def simplified_type(field_type)
          case field_type
            when /int|bigint|smallint|tinyint/i        then :integer
            when /float|double|real/i                  then :float
            when /decimal|money|numeric|smallmoney/i   then :decimal
            when /text|ntext/i                         then :text
            when /binary|image|varbinary/i             then :binary
            when /char|nchar|nvarchar|string|varchar/i then :string
            when /bit/i                                then :boolean
            when /datetime|smalldatetime/i             then :datetime
            else                                       super
          end
        end

        def self.string_to_binary(value)
          "0x#{value.unpack("H*")[0]}"
        end

        def self.binary_to_string(value)
          # FIXME: sybase-ctlib uses separate sql method for binary columns.
          value
        end
      end # class ColumnWithIdentity

      # Sybase adapter
      def initialize(connection, database, config = {}, logger = nil)
        super(connection, logger)
        context = connection.context
        context.init(logger)
        @config = config
        @numconvert = config.has_key?(:numconvert) ? config[:numconvert] : true
        @limit = @offset = 0
        unless connection.sql_norow("USE #{database}")
          raise "Cannot USE #{database}"
        end
      end

      def native_database_types
        {
          :primary_key => "numeric(9,0) IDENTITY PRIMARY KEY",
          :string      => { :name => "varchar", :limit => 255 },
          :text        => { :name => "text" },
          :integer     => { :name => "int" },
          :float       => { :name => "float", :limit => 8 },
          :decimal     => { :name => "decimal" },
          :datetime    => { :name => "datetime" },
          :timestamp   => { :name => "timestamp" },
          :time        => { :name => "time" },
          :date        => { :name => "datetime" },
          :binary      => { :name => "image"},
          :boolean     => { :name => "bit" }
        }
      end

      def type_to_sql(type, limit = nil, precision = nil, scale = nil) #:nodoc:
        return super unless type.to_s == 'integer'
        if !limit.nil? && limit < 4
          'smallint'
        else
          'integer'
        end
      end

      def adapter_name
        'Sybase'
      end

      def active?
        !(@connection.connection.nil? || @connection.connection_dead?)
      end

      def disconnect!
        @connection.close rescue nil
      end

      def reconnect!
        raise "Sybase Connection Adapter does not yet support reconnect!"
        # disconnect!
        # connect! # Not yet implemented
      end

      def table_alias_length
        30
      end

      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        begin
          table_name = get_table_name(sql)
          col = get_identity_column(table_name)
          ii_enabled = false

          if col != nil
            if query_contains_identity_column(sql, col)
              begin
                enable_identity_insert(table_name, true)
                ii_enabled = true
              rescue Exception => e
                raise ActiveRecordError, "IDENTITY_INSERT could not be turned ON"
              end
            end
          end

          log(sql, name) do
            execute(sql, name)
            ident = select_one("SELECT @@IDENTITY AS last_id")["last_id"]
            id_value || ident
          end
        ensure
          if ii_enabled
            begin
              enable_identity_insert(table_name, false)
            rescue Exception => e
              raise ActiveRecordError, "IDENTITY_INSERT could not be turned OFF"
            end
          end
        end
      end

      def execute(sql, name = nil)
        raw_execute(sql, name)
        @connection.results[0].row_count
      end

      def begin_db_transaction()    raw_execute "BEGIN TRAN" end
      def commit_db_transaction()   raw_execute "COMMIT TRAN" end
      def rollback_db_transaction() raw_execute "ROLLBACK TRAN" end

      def current_database
        select_one("select DB_NAME() as name")["name"]
      end

      def tables(name = nil)
        select("select name from sysobjects where type='U'", name).map { |row| row['name'] }
      end

      def indexes(table_name, name = nil)
        select("exec sp_helpindex #{table_name}", name).map do |index|
          unique = index["index_description"] =~ /unique/
          primary = index["index_description"] =~ /^clustered/
          if !primary
            cols = index["index_keys"].split(", ").each { |col| col.strip! }
            IndexDefinition.new(table_name, index["index_name"], unique, cols)
          end
        end.compact
      end

      def columns(table_name, name = nil)
        sql = <<SQLTEXT
SELECT col.name AS name, type.name AS type, col.prec, col.scale,
  col.length, col.status, obj.sysstat2, def.text
 FROM sysobjects obj, syscolumns col, systypes type, syscomments def
 WHERE obj.id = col.id AND col.usertype = type.usertype AND type.name != 'timestamp' 
  AND col.cdefault *= def.id AND obj.type = 'U' AND obj.name = '#{table_name}' ORDER BY col.colid
SQLTEXT
        @logger.debug "Get Column Info for table '#{table_name}'" if @logger
        @connection.set_rowcount(0)
        @connection.sql(sql)

        raise "SQL Command for table_structure for #{table_name} failed\nMessage: #{@connection.context.message}" if @connection.context.failed?
        return nil if @connection.cmd_fail?

        @connection.top_row_result.rows.map do |row|
          name, type, prec, scale, length, status, sysstat2, default = row
          name.sub!(/_$/o, '')
          type = normalize_type(type, prec, scale, length)
          default_value = nil
          if default =~ /DEFAULT\s+(.+)/o
            default_value = $1.strip
            default_value = default_value[1...-1] if default_value =~ /^['"]/o
          end
          nullable = (status & 8) == 8
          identity = status >= 128
          primary = (sysstat2 & 8) == 8
          ColumnWithIdentity.new(name, default_value, type, nullable, identity, primary)
        end
      end

      def quoted_true
        "1"
      end

      def quoted_false
        "0"
      end

      def quote(value, column = nil)
        return value.quoted_id if value.respond_to?(:quoted_id)

        case value
          when String                
            if column && column.type == :binary && column.class.respond_to?(:string_to_binary)
              "#{quote_string(column.class.string_to_binary(value))}"
            elsif @numconvert && force_numeric?(column) && value =~ /^[+-]?[0-9]+$/o
              value
            else
              "'#{quote_string(value)}'"
            end
          when NilClass              then (column && column.type == :boolean) ? '0' : "NULL"
          when TrueClass             then '1'
          when FalseClass            then '0'
          when Float, Fixnum, Bignum then force_numeric?(column) ? value.to_s : "'#{value.to_s}'"
          else
            if value.acts_like?(:time)
              "'#{value.strftime("%Y-%m-%d %H:%M:%S")}'"
            else
              super
            end
        end
      end

      # True if column is explicitly declared non-numeric, or
      # if column is nil (not specified).
      def force_numeric?(column)
        (column.nil? || [:integer, :float, :decimal].include?(column.type))
      end

      def quote_string(s)
        s.gsub(/'/, "''") # ' (for ruby-mode)
      end

      def quote_column_name(name)
        # If column name is close to max length, skip the quotes, since they
        # seem to count as part of the length.
        ((name.to_s.length + 2) <= table_alias_length) ? "[#{name}]" : name.to_s
      end

      def add_limit_offset!(sql, options) # :nodoc:
        @limit = options[:limit]
        @offset = options[:offset]
        if use_temp_table?
          # Use temp table to hack offset with Sybase
          sql.sub!(/ FROM /i, ' INTO #artemp FROM ')
        elsif zero_limit?
          # "SET ROWCOUNT 0" turns off limits, so we have
          # to use a cheap trick.
          if sql =~ /WHERE/i
            sql.sub!(/WHERE/i, 'WHERE 1 = 2 AND ')
          elsif sql =~ /ORDER\s+BY/i
            sql.sub!(/ORDER\s+BY/i, 'WHERE 1 = 2 ORDER BY')
          else
            sql << 'WHERE 1 = 2'
          end
        end
      end

      def add_lock!(sql, options) #:nodoc:
        @logger.info "Warning: Sybase :lock option '#{options[:lock].inspect}' not supported" if @logger && options.has_key?(:lock)
        sql
      end

      def supports_migrations? #:nodoc:
        true
      end

      def rename_table(name, new_name)
        execute "EXEC sp_rename '#{name}', '#{new_name}'"
      end

      def rename_column(table, column, new_column_name)
        execute "EXEC sp_rename '#{table}.#{column}', '#{new_column_name}'"
      end

      def change_column(table_name, column_name, type, options = {}) #:nodoc:
        begin
          execute "ALTER TABLE #{table_name} MODIFY #{column_name} #{type_to_sql(type, options[:limit])}"
        rescue StatementInvalid => e
          # Swallow exception and reset context if no-op.
          raise e unless e.message =~ /no columns to drop, add or modify/
          @connection.context.reset
        end

        if options.has_key?(:default)
          remove_default_constraint(table_name, column_name)
          execute "ALTER TABLE #{table_name} REPLACE #{column_name} DEFAULT #{quote options[:default]}"
        end
      end

      def remove_column(table_name, column_name)
        remove_default_constraint(table_name, column_name)
        execute "ALTER TABLE #{table_name} DROP #{column_name}"
      end

      def remove_default_constraint(table_name, column_name)
        sql = "select def.name from sysobjects def, syscolumns col, sysobjects tab where col.cdefault = def.id and col.name = '#{column_name}' and tab.name = '#{table_name}' and col.id = tab.id"
        select(sql).each do |constraint|
          execute "ALTER TABLE #{table_name} DROP CONSTRAINT #{constraint["name"]}"
        end
      end

      def remove_index(table_name, options = {})
        execute "DROP INDEX #{table_name}.#{index_name(table_name, options)}"
      end

      def add_column_options!(sql, options) #:nodoc:
        sql << " DEFAULT #{quote(options[:default], options[:column])}" if options_include_default?(options)

        if check_null_for_column?(options[:column], sql)
          sql << (options[:null] == false ? " NOT NULL" : " NULL")
        end
        sql
      end

      def enable_identity_insert(table_name, enable = true)
        if has_identity_column(table_name)
          execute "SET IDENTITY_INSERT #{table_name} #{enable ? 'ON' : 'OFF'}"
        end
      end

    private
      def check_null_for_column?(col, sql)
        # Sybase columns are NOT NULL by default, so explicitly set NULL
        # if :null option is omitted.  Disallow NULLs for boolean.
        type = col.nil? ? "" : col[:type]

        # Ignore :null if a primary key
        return false if type =~ /PRIMARY KEY/i

        # Ignore :null if a :boolean or BIT column
        if (sql =~ /\s+bit(\s+DEFAULT)?/i) || type == :boolean
          # If no default clause found on a boolean column, add one.
          sql << " DEFAULT 0" if $1.nil?
          return false
        end
        true
      end

      # Return the last value of the identity global value.
      def last_insert_id
        @connection.sql("SELECT @@IDENTITY")
        unless @connection.cmd_fail?
          id = @connection.top_row_result.rows.first.first
          if id
            id = id.to_i
            id = nil if id == 0
          end
        else
          id = nil
        end
        id
      end

      def affected_rows(name = nil)
        @connection.sql("SELECT @@ROWCOUNT")
        unless @connection.cmd_fail?
          count = @connection.top_row_result.rows.first.first
          count = count.to_i if count
        else
          0
        end
      end

      # If limit is not set at all, we can ignore offset;
      # if limit *is* set but offset is zero, use normal select
      # with simple SET ROWCOUNT.  Thus, only use the temp table
      # if limit is set and offset > 0.
      def use_temp_table?
        !@limit.nil? && !@offset.nil? && @offset > 0
      end

      def zero_limit?
        !@limit.nil? && @limit == 0
      end

      def raw_execute(sql, name = nil)
        log(sql, name) do
          @connection.context.reset
          @logger.debug "Setting row count to (#{@limit})" if @logger && @limit
          @connection.set_rowcount(@limit || 0)
          if sql =~ /^\s*SELECT/i
            @connection.sql(sql)
          else
            @connection.sql_norow(sql)
          end
          @limit = @offset = nil
          if @connection.cmd_fail? or @connection.context.failed?
            raise "SQL Command Failed for #{name}: #{sql}\nMessage: #{@connection.context.message}"
          end
        end
      end

      # Select limit number of rows starting at optional offset.
      def select(sql, name = nil)
        if !use_temp_table?
          execute(sql, name)
        else
          log(sql, name) do
            # Select into a temp table and prune results
            @logger.debug "Selecting #{@limit + (@offset || 0)} or fewer rows into #artemp" if @logger
            @connection.context.reset
            @connection.set_rowcount(@limit + (@offset || 0))
            @connection.sql_norow(sql)  # Select into temp table
            @logger.debug "Deleting #{@offset || 0} or fewer rows from #artemp" if @logger
            @connection.set_rowcount(@offset || 0)
            @connection.sql_norow("delete from #artemp") # Delete leading rows
            @connection.set_rowcount(0)
            @connection.sql("select * from #artemp") # Return the rest
          end
        end

        raise StatementInvalid, "SQL Command Failed for #{name}: #{sql}\nMessage: #{@connection.context.message}" if @connection.context.failed? or @connection.cmd_fail?
      
        rows = []
        results = @connection.top_row_result
        if results && results.rows.length > 0
          fields = results.columns.map { |column| column.sub(/_$/, '') }
          results.rows.each do |row|
            hashed_row = {}
            row.zip(fields) { |cell, column| hashed_row[column] = cell }
            rows << hashed_row
          end
        end
        @connection.sql_norow("drop table #artemp") if use_temp_table?
        @limit = @offset = nil
        rows
      end

      def get_table_name(sql)
        if sql =~ /^\s*insert\s+into\s+([^\(\s]+)\s*|^\s*update\s+([^\(\s]+)\s*/i
          $1
        elsif sql =~ /from\s+([^\(\s]+)\s*/i
          $1
        else
          nil
        end
      end

      def has_identity_column(table_name)
        !get_identity_column(table_name).nil?
      end

      def get_identity_column(table_name)
        @id_columns ||= {}
        if !@id_columns.has_key?(table_name)
          @logger.debug "Looking up identity column for table '#{table_name}'" if @logger
          col = columns(table_name).detect { |col| col.identity }
          @id_columns[table_name] = col.nil? ? nil : col.name
        end
        @id_columns[table_name]
      end

      def query_contains_identity_column(sql, col)
        sql =~ /\[#{col}\]/
      end

      # Resolve all user-defined types (udt) to their fundamental types.
      def resolve_type(field_type)
        (@udts ||= {})[field_type] ||= select_one("sp_help #{field_type}")["Storage_type"].strip
      end

      def normalize_type(field_type, prec, scale, length)
        has_scale = (!scale.nil? && scale > 0)
        type = if field_type =~ /numeric/i and !has_scale
          'int'
        elsif field_type =~ /money/i
          'numeric'
        else
          resolve_type(field_type.strip)
        end

        spec = if prec
          has_scale ? "(#{prec},#{scale})" : "(#{prec})"
        elsif length && !(type =~ /date|time|text/)
          "(#{length})"
        else
          ''
        end
        "#{type}#{spec}"
      end
    end # class SybaseAdapter

    class SybaseAdapterContext < SybSQLContext
      DEADLOCK = 1205
      attr_reader :message

      def init(logger = nil)
        @deadlocked = false
        @failed = false
        @logger = logger
        @message = nil
      end

      def srvmsgCB(con, msg)
        # Do not log change of context messages.
        if msg['severity'] == 10 or msg['severity'] == 0
          return true
        end

        if msg['msgnumber'] == DEADLOCK
          @deadlocked = true
        else
          @logger.info "SQL Command failed!" if @logger
          @failed = true
        end

        if @logger
          @logger.error "** SybSQLContext Server Message: **"
          @logger.error "  Message number #{msg['msgnumber']} Severity #{msg['severity']} State #{msg['state']} Line #{msg['line']}"
          @logger.error "  Server #{msg['srvname']}"
          @logger.error "  Procedure #{msg['proc']}"
          @logger.error "  Message String:  #{msg['text']}"
        end

        @message = msg['text']

        true
      end

      def deadlocked?
        @deadlocked
      end

      def failed?
        @failed
      end

      def reset
        @deadlocked = false
        @failed = false
        @message = nil
      end

      def cltmsgCB(con, msg)
        return true unless ( msg.kind_of?(Hash) )
        unless ( msg[ "severity" ] ) then
          return true
        end

        if @logger
          @logger.error "** SybSQLContext Client-Message: **"
          @logger.error "  Message number: LAYER=#{msg[ 'layer' ]} ORIGIN=#{msg[ 'origin' ]} SEVERITY=#{msg[ 'severity' ]} NUMBER=#{msg[ 'number' ]}"
          @logger.error "  Message String: #{msg['msgstring']}"
          @logger.error "  OS Error: #{msg['osstring']}"

          @message = msg['msgstring']
        end

        @failed = true

        # Not retry , CS_CV_RETRY_FAIL( probability TimeOut ) 
        if( msg[ 'severity' ] == "RETRY_FAIL" ) then
          @timeout_p = true
          return false
        end

        return true
      end
    end # class SybaseAdapterContext

  end # module ConnectionAdapters
end # module ActiveRecord


# Allow identity inserts for fixtures.
require "active_record/fixtures"
class Fixtures
  alias :original_insert_fixtures :insert_fixtures

  def insert_fixtures
    if @connection.instance_of?(ActiveRecord::ConnectionAdapters::SybaseAdapter)
      values.each do |fixture|
        @connection.enable_identity_insert(table_name, true)
        @connection.execute "INSERT INTO #{@table_name} (#{fixture.key_list}) VALUES (#{fixture.value_list})", 'Fixture Insert'
        @connection.enable_identity_insert(table_name, false)
      end
    else
      original_insert_fixtures
    end
  end
end

rescue LoadError => cannot_require_sybase
  # Couldn't load sybase adapter
end
