require 'active_record/connection_adapters/abstract_adapter'

# sqlserver_adapter.rb -- ActiveRecord adapter for Microsoft SQL Server
#
# Author: Joey Gibson <joey@joeygibson.com>
# Date:   10/14/2004
#
# Modifications: DeLynn Berry <delynnb@megastarfinancial.com>
# Date: 3/22/2005
#
# Modifications (ODBC): Mark Imbriaco <mark.imbriaco@pobox.com>
# Date: 6/26/2005
#
# Current maintainer: Ryan Tomayko <rtomayko@gmail.com>
#
# Modifications (Migrations): Tom Ward <tom@popdog.net>
# Date: 27/10/2005
#

module ActiveRecord
  class Base
    def self.sqlserver_connection(config) #:nodoc:
      require_library_or_gem 'dbi' unless self.class.const_defined?(:DBI)
      
      config = config.symbolize_keys

      mode        = config[:mode] ? config[:mode].to_s.upcase : 'ADO'
      username    = config[:username] ? config[:username].to_s : 'sa'
      password    = config[:password] ? config[:password].to_s : ''
      if mode == "ODBC"
        raise ArgumentError, "Missing DSN. Argument ':dsn' must be set in order for this adapter to work." unless config.has_key?(:dsn)
        dsn       = config[:dsn]
        driver_url = "DBI:ODBC:#{dsn}"
      else
        raise ArgumentError, "Missing Database. Argument ':database' must be set in order for this adapter to work." unless config.has_key?(:database)
        database  = config[:database]
        host      = config[:host] ? config[:host].to_s : 'localhost'
        driver_url = "DBI:ADO:Provider=SQLOLEDB;Data Source=#{host};Initial Catalog=#{database};User Id=#{username};Password=#{password};"
      end
      conn      = DBI.connect(driver_url, username, password)

      conn["AutoCommit"] = true
      ConnectionAdapters::SQLServerAdapter.new(conn, logger, [driver_url, username, password])
    end
  end # class Base

  module ConnectionAdapters
    class ColumnWithIdentity < Column# :nodoc:
      attr_reader :identity, :is_special, :scale

      def initialize(name, default, sql_type = nil, is_identity = false, scale_value = 0)
        super(name, default, sql_type)
        @identity = is_identity
        @is_special = sql_type =~ /text|ntext|image/i ? true : false
        @scale = scale_value
        # SQL Server only supports limits on *char and float types
        @limit = nil unless @type == :float or @type == :string
      end

      def simplified_type(field_type)
        case field_type
          when /int|bigint|smallint|tinyint/i                        then :integer
          when /float|double|decimal|money|numeric|real|smallmoney/i then @scale == 0 ? :integer : :float
          when /datetime|smalldatetime/i                             then :datetime
          when /timestamp/i                                          then :timestamp
          when /time/i                                               then :time
          when /text|ntext/i                                         then :text
          when /binary|image|varbinary/i                             then :binary
          when /char|nchar|nvarchar|string|varchar/i                 then :string
          when /bit/i                                                then :boolean
          when /uniqueidentifier/i                                   then :string
        end
      end

      def type_cast(value)
        return nil if value.nil? || value =~ /^\s*null\s*$/i
        case type
        when :string    then value
        when :integer   then value == true || value == false ? value == true ? 1 : 0 : value.to_i
        when :float     then value.to_f
        when :datetime  then cast_to_datetime(value)
        when :timestamp then cast_to_time(value)
        when :time      then cast_to_time(value)
        when :date      then cast_to_datetime(value)
        when :boolean   then value == true or (value =~ /^t(rue)?$/i) == 0 or value.to_s == '1'
        else value
        end
      end

      def cast_to_time(value)
        return value if value.is_a?(Time)
        time_array = ParseDate.parsedate(value)
        time_array[0] ||= 2000
        time_array[1] ||= 1
        time_array[2] ||= 1
        Time.send(Base.default_timezone, *time_array) rescue nil
      end

      def cast_to_datetime(value)
        if value.is_a?(Time)
          if value.year != 0 and value.month != 0 and value.day != 0
            return value
          else
            return Time.mktime(2000, 1, 1, value.hour, value.min, value.sec) rescue nil
          end
        end
        return cast_to_time(value) if value.is_a?(Date) or value.is_a?(String) rescue nil
        value
      end

      # These methods will only allow the adapter to insert binary data with a length of 7K or less
      # because of a SQL Server statement length policy.
      def self.string_to_binary(value)
        value.gsub(/(\r|\n|\0|\x1a)/) do
          case $1
            when "\r"   then  "%00"
            when "\n"   then  "%01"
            when "\0"   then  "%02"
            when "\x1a" then  "%03"
          end
        end
      end

      def self.binary_to_string(value)
        value.gsub(/(%00|%01|%02|%03)/) do
          case $1
            when "%00"    then  "\r"
            when "%01"    then  "\n"
            when "%02\0"  then  "\0"
            when "%03"    then  "\x1a"
          end
        end
      end
    end

    # In ADO mode, this adapter will ONLY work on Windows systems, 
    # since it relies on Win32OLE, which, to my knowledge, is only 
    # available on Windows.
    #
    # This mode also relies on the ADO support in the DBI module. If you are using the
    # one-click installer of Ruby, then you already have DBI installed, but
    # the ADO module is *NOT* installed. You will need to get the latest
    # source distribution of Ruby-DBI from http://ruby-dbi.sourceforge.net/
    # unzip it, and copy the file 
    # <tt>src/lib/dbd_ado/ADO.rb</tt> 
    # to
    # <tt>X:/Ruby/lib/ruby/site_ruby/1.8/DBD/ADO/ADO.rb</tt> 
    # (you will more than likely need to create the ADO directory).
    # Once you've installed that file, you are ready to go.
    #
    # In ODBC mode, the adapter requires the ODBC support in the DBI module which requires
    # the Ruby ODBC module.  Ruby ODBC 0.996 was used in development and testing,
    # and it is available at http://www.ch-werner.de/rubyodbc/
    #
    # Options:
    #
    # * <tt>:mode</tt>      -- ADO or ODBC. Defaults to ADO.
    # * <tt>:username</tt>  -- Defaults to sa.
    # * <tt>:password</tt>  -- Defaults to empty string.
    #
    # ADO specific options:
    #
    # * <tt>:host</tt>      -- Defaults to localhost.
    # * <tt>:database</tt>  -- The name of the database. No default, must be provided.
    #
    # ODBC specific options:                   
    #
    # * <tt>:dsn</tt>       -- Defaults to nothing.
    #
    # ADO code tested on Windows 2000 and higher systems,
    # running ruby 1.8.2 (2004-07-29) [i386-mswin32], and SQL Server 2000 SP3.
    #
    # ODBC code tested on a Fedora Core 4 system, running FreeTDS 0.63, 
    # unixODBC 2.2.11, Ruby ODBC 0.996, Ruby DBI 0.0.23 and Ruby 1.8.2.
    # [Linux strongmad 2.6.11-1.1369_FC4 #1 Thu Jun 2 22:55:56 EDT 2005 i686 i686 i386 GNU/Linux]
    class SQLServerAdapter < AbstractAdapter
    
      def initialize(connection, logger, connection_options=nil)
        super(connection, logger)
        @connection_options = connection_options
      end

      def native_database_types
        {
          :primary_key => "int NOT NULL IDENTITY(1, 1) PRIMARY KEY",
          :string      => { :name => "varchar", :limit => 255  },
          :text        => { :name => "text" },
          :integer     => { :name => "int" },
          :float       => { :name => "float", :limit => 8 },
          :datetime    => { :name => "datetime" },
          :timestamp   => { :name => "datetime" },
          :time        => { :name => "datetime" },
          :date        => { :name => "datetime" },
          :binary      => { :name => "image"},
          :boolean     => { :name => "bit"}
        }
      end

      def adapter_name
        'SQLServer'
      end
      
      def supports_migrations? #:nodoc:
        true
      end

      # CONNECTION MANAGEMENT ====================================#

      # Returns true if the connection is active.
      def active?
        @connection.execute("SELECT 1") { }
        true
      rescue DBI::DatabaseError, DBI::InterfaceError
        false
      end

      # Reconnects to the database, returns false if no connection could be made.
      def reconnect!
        @connection.disconnect rescue nil
        @connection = DBI.connect(*@connection_options)
      rescue DBI::DatabaseError => e
        @logger.warn "#{adapter_name} reconnection failed: #{e.message}" if @logger
        false
      end

      def select_all(sql, name = nil)
        select(sql, name)
      end

      def select_one(sql, name = nil)
        add_limit!(sql, :limit => 1)
        result = select(sql, name)
        result.nil? ? nil : result.first
      end

      def columns(table_name, name = nil)
        return [] if table_name.blank?
        table_name = table_name.to_s if table_name.is_a?(Symbol)
        table_name = table_name.split('.')[-1] unless table_name.nil?
        sql = "SELECT COLUMN_NAME as ColName, COLUMN_DEFAULT as DefaultValue, DATA_TYPE as ColType, COL_LENGTH('#{table_name}', COLUMN_NAME) as Length, COLUMNPROPERTY(OBJECT_ID('#{table_name}'), COLUMN_NAME, 'IsIdentity') as IsIdentity, NUMERIC_SCALE as Scale FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '#{table_name}'"
        # Comment out if you want to have the Columns select statment logged.
        # Personnally, I think it adds unneccessary bloat to the log. 
        # If you do comment it out, make sure to un-comment the "result" line that follows
        result = log(sql, name) { @connection.select_all(sql) }
        #result = @connection.select_all(sql)
        columns = []
        result.each { |field| columns << ColumnWithIdentity.new(field[:ColName], field[:DefaultValue].to_s.gsub!(/[()\']/,"") =~ /null/ ? nil : field[:DefaultValue], "#{field[:ColType]}(#{field[:Length]})", field[:IsIdentity] == 1 ? true : false, field[:Scale]) }
        columns
      end

      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        begin
          table_name = get_table_name(sql)
          col = get_identity_column(table_name)
          ii_enabled = false

          if col != nil
            if query_contains_identity_column(sql, col)
              begin
                execute enable_identity_insert(table_name, true)
                ii_enabled = true
              rescue Exception => e
                raise ActiveRecordError, "IDENTITY_INSERT could not be turned ON"
              end
            end
          end
          log(sql, name) do
            @connection.execute(sql)
            id_value || select_one("SELECT @@IDENTITY AS Ident")["Ident"]
          end
        ensure
          if ii_enabled
            begin
              execute enable_identity_insert(table_name, false)
            rescue Exception => e
              raise ActiveRecordError, "IDENTITY_INSERT could not be turned OFF"
            end
          end
        end
      end

      def execute(sql, name = nil)
        if sql =~ /^\s*INSERT/i
          insert(sql, name)
        elsif sql =~ /^\s*UPDATE|^\s*DELETE/i
          log(sql, name) do
            @connection.execute(sql)
            retVal = select_one("SELECT @@ROWCOUNT AS AffectedRows")["AffectedRows"]
          end
        else
          log(sql, name) { @connection.execute(sql) }
        end
      end

      def update(sql, name = nil)
        execute(sql, name)
      end
      alias_method :delete, :update

      def begin_db_transaction
        @connection["AutoCommit"] = false
      rescue Exception => e
        @connection["AutoCommit"] = true
      end

      def commit_db_transaction
        @connection.commit
      ensure
        @connection["AutoCommit"] = true
      end

      def rollback_db_transaction
        @connection.rollback
      ensure
        @connection["AutoCommit"] = true
      end

      def quote(value, column = nil)
        case value
          when String                
            if column && column.type == :binary
              "'#{quote_string(column.class.string_to_binary(value))}'"
            else
              "'#{quote_string(value)}'"
            end
          when NilClass              then "NULL"
          when TrueClass             then '1'
          when FalseClass            then '0'
          when Float, Fixnum, Bignum then value.to_s
          when Date                  then "'#{value.to_s}'" 
          when Time, DateTime        then "'#{value.strftime("%Y-%m-%d %H:%M:%S")}'"
          else                            "'#{quote_string(value.to_yaml)}'"
        end
      end

      def quote_string(string)
        string.gsub(/\'/, "''")
      end

      def quoted_true
        "1"
      end
      
      def quoted_false
        "0"
      end

      def quote_column_name(name)
        "[#{name}]"
      end

      def add_limit_offset!(sql, options)
        if options[:limit] and options[:offset]
          total_rows = @connection.select_all("SELECT count(*) as TotalRows from (#{sql.gsub(/\bSELECT\b/i, "SELECT TOP 1000000000")}) tally")[0][:TotalRows].to_i
          if (options[:limit] + options[:offset]) >= total_rows
            options[:limit] = (total_rows - options[:offset] >= 0) ? (total_rows - options[:offset]) : 0
          end
          sql.sub!(/^\s*SELECT/i, "SELECT * FROM (SELECT TOP #{options[:limit]} * FROM (SELECT TOP #{options[:limit] + options[:offset]} ")
          sql << ") AS tmp1"
          if options[:order]
            options[:order] = options[:order].split(',').map do |field|
              parts = field.split(" ")
              tc = parts[0]
              if sql =~ /\.\[/ and tc =~ /\./ # if column quoting used in query
                tc.gsub!(/\./, '\\.\\[')
                tc << '\\]'
              end
              if sql =~ /#{tc} AS (t\d_r\d\d?)/
                  parts[0] = $1
              end
              parts.join(' ')
            end.join(', ')
            sql << " ORDER BY #{change_order_direction(options[:order])}) AS tmp2 ORDER BY #{options[:order]}"
          else
            sql << " ) AS tmp2"
          end
        elsif sql !~ /^\s*SELECT (@@|COUNT\()/i
          sql.sub!(/^\s*SELECT/i, "SELECT TOP #{options[:limit]}") unless options[:limit].nil?
        end
      end

      def recreate_database(name)
        drop_database(name)
        create_database(name)
      end

      def drop_database(name)
        execute "DROP DATABASE #{name}"
      end

      def create_database(name)
        execute "CREATE DATABASE #{name}"
      end

      def tables(name = nil)
        execute("SELECT table_name from information_schema.tables WHERE table_type = 'BASE TABLE'", name).inject([]) do |tables, field|
          table_name = field[0]
          tables << table_name unless table_name == 'dtproperties'
          tables
        end
      end

      def indexes(table_name, name = nil)
        indexes = []
        execute("EXEC sp_helpindex #{table_name}", name).each do |index| 
          unique = index[1] =~ /unique/
          primary = index[1] =~ /primary key/
          if !primary
            indexes << IndexDefinition.new(table_name, index[0], unique, index[2].split(", "))
          end
        end
        indexes
      end
            
      def rename_table(name, new_name)
        execute "EXEC sp_rename '#{name}', '#{new_name}'"
      end
      
      def remove_column(table_name, column_name)
        execute "ALTER TABLE #{table_name} DROP COLUMN #{column_name}"
      end 
      
      def rename_column(table, column, new_column_name)
        execute "EXEC sp_rename '#{table}.#{column}', '#{new_column_name}'"
      end
      
      def change_column(table_name, column_name, type, options = {}) #:nodoc:
        sql_commands = ["ALTER TABLE #{table_name} ALTER COLUMN #{column_name} #{type_to_sql(type, options[:limit])}"]
        if options[:default]
          remove_default_constraint(table_name, column_name)
          sql_commands << "ALTER TABLE #{table_name} ADD CONSTRAINT DF_#{table_name}_#{column_name} DEFAULT #{options[:default]} FOR #{column_name}"
        end
        sql_commands.each {|c|
          execute(c)
        }
      end
      
      def remove_column(table_name, column_name)
        remove_default_constraint(table_name, column_name)
        execute "ALTER TABLE #{table_name} DROP COLUMN #{column_name}"
      end
      
      def remove_default_constraint(table_name, column_name)
        defaults = select "select def.name from sysobjects def, syscolumns col, sysobjects tab where col.cdefault = def.id and col.name = '#{column_name}' and tab.name = '#{table_name}' and col.id = tab.id"
        defaults.each {|constraint|
          execute "ALTER TABLE #{table_name} DROP CONSTRAINT #{constraint["name"]}"
        }
      end
      
      def remove_index(table_name, options = {})
        execute "DROP INDEX #{table_name}.#{index_name(table_name, options)}"
      end

      def type_to_sql(type, limit = nil) #:nodoc:
        native = native_database_types[type]
        # if there's no :limit in the default type definition, assume that type doesn't support limits
        limit = native[:limit] ? limit || native[:limit] : nil
        column_type_sql = native[:name]
        column_type_sql << "(#{limit})" if limit
        column_type_sql
      end

      private
        def select(sql, name = nil)
          rows = []
          repair_special_columns(sql)
          log(sql, name) do
            @connection.select_all(sql) do |row|
              record = {}
              row.column_names.each do |col|
                record[col] = row[col]
                record[col] = record[col].to_time if record[col].is_a? DBI::Timestamp
              end
              rows << record
            end
          end
          rows
        end

        def enable_identity_insert(table_name, enable = true)
          if has_identity_column(table_name)
            "SET IDENTITY_INSERT #{table_name} #{enable ? 'ON' : 'OFF'}"
          end
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
          @table_columns = {} unless @table_columns
          @table_columns[table_name] = columns(table_name) if @table_columns[table_name] == nil
          @table_columns[table_name].each do |col|
            return col.name if col.identity
          end

          return nil
        end

        def query_contains_identity_column(sql, col)
          sql =~ /\[#{col}\]/
        end

        def change_order_direction(order)
          case order
            when  /\bDESC\b/i     then order.gsub(/\bDESC\b/i, "ASC")
            when  /\bASC\b/i      then order.gsub(/\bASC\b/i, "DESC")
            else                  String.new(order).split(',').join(' DESC,') + ' DESC'
          end
        end

        def get_special_columns(table_name)
          special = []
          @table_columns ||= {}
          @table_columns[table_name] ||= columns(table_name)
          @table_columns[table_name].each do |col|
            special << col.name if col.is_special
          end
          special
        end

        def repair_special_columns(sql)
          special_cols = get_special_columns(get_table_name(sql))
          for col in special_cols.to_a
            sql.gsub!(Regexp.new(" #{col.to_s} = "), " #{col.to_s} LIKE ")
            sql.gsub!(/ORDER BY #{col.to_s}/i, '')
          end
          sql
        end

    end #class SQLServerAdapter < AbstractAdapter
  end #module ConnectionAdapters
end #module ActiveRecord
