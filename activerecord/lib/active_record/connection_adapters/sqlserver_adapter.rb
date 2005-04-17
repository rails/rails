require 'active_record/connection_adapters/abstract_adapter'

# sqlserver_adapter.rb -- ActiveRecord adapter for Microsoft SQL Server
#
# Author: Joey Gibson <joey@joeygibson.com>
# Date:   10/14/2004
#
# Modifications: DeLynn Berry <delynnb@megastarfinancial.com>
# Date: 3/22/2005
#
# This adapter will ONLY work on Windows systems, since it relies on Win32OLE, which,
# to my knowledge, is only available on Window.
#
# It relies on the ADO support in the DBI module. If you are using the
# one-click installer of Ruby, then you already have DBI installed, but
# the ADO module is *NOT* installed. You will need to get the latest
# source distribution of Ruby-DBI from http://ruby-dbi.sourceforge.net/
# unzip it, and copy the file <tt>src/lib/dbd_ado/ADO.rb</tt> to
# <tt>X:/Ruby/lib/ruby/site_ruby/1.8/DBD/ADO/ADO.rb</tt> (you will need to create
# the ADO directory). Once you've installed that file, you are ready to go.
#
# Options:
#
# * <tt>:host</tt> -- Defaults to localhost
# * <tt>:username</tt> -- Defaults to sa
# * <tt>:password</tt> -- Defaults to nothing
# * <tt>:database</tt> -- The name of the database. No default, must be provided.
#
# I have tested this code on a WindowsXP Pro SP1 system,
# ruby 1.8.2 (2004-07-29) [i386-mswin32], SQL Server 2000.
#
module ActiveRecord
  class Base
    def self.sqlserver_connection(config) #:nodoc:
      require_library_or_gem 'dbi' unless self.class.const_defined?(:DBI)
      
      symbolize_strings_in_hash(config)

      host     = config[:host]
      username = config[:username] ? config[:username].to_s : 'sa'
      password = config[:password].to_s

      if config.has_key?(:database)
        database = config[:database]
      else
        raise ArgumentError, "No database specified. Missing argument: database."
      end

      conn = DBI.connect("DBI:ADO:Provider=SQLOLEDB;Data Source=#{host};Initial Catalog=#{database};User Id=#{username};Password=#{password};")
      conn["AutoCommit"] = true

      ConnectionAdapters::SQLServerAdapter.new(conn, logger)
    end
  end

  module ConnectionAdapters
    class ColumnWithIdentity < Column# :nodoc:
      attr_reader :identity, :scale

      def initialize(name, default, sql_type = nil, is_identity = false, scale_value = 0)
        super(name, default, sql_type)
        @scale = scale_value
        @identity = is_identity
      end

      def simplified_type(field_type)
        case field_type
          when /int|bigint|smallint|tinyint/i                        : :integer
          when /float|double|decimal|money|numeric|real|smallmoney/i : @scale == 0 ? :integer : :float
          when /datetime|smalldatetime/i                             : :datetime
          when /timestamp/i                                          : :timestamp
          when /time/i                                               : :time
          when /text|ntext/i                                         : :text
          when /binary|image|varbinary/i                             : :binary
          when /char|nchar|nvarchar|string|varchar/i                 : :string
          when /bit/i                                                : :boolean
        end
      end

      def type_cast(value)
        return nil if value.nil? || value =~ /^\s*null\s*$/i
        case type
        when :string    then value
        when :integer   then value == true || value == false ? value == true ? '1' : '0' : value.to_i
        when :float     then value.to_f
        when :datetime  then cast_to_date_or_time(value)
        when :timestamp then cast_to_time(value)
        when :time      then cast_to_time(value)
        else value
        end
      end

      def cast_to_date_or_time(value)
        return value if value.is_a?(Date)
        guess_date_or_time (value.is_a?(Time)) ? value : cast_to_time(value)
      end

      def cast_to_time(value)
        return value if value.is_a?(Time)
        time_array = ParseDate.parsedate value
        time_array[0] ||= 2000; time_array[1] ||= 1; time_array[2] ||= 1;
        Time.send Base.default_timezone, *time_array
      end

      def guess_date_or_time(value)
        (value.hour == 0 and value.min == 0 and value.sec == 0) ?
          Date.new(value.year, value.month, value.day) : value
      end

      # These methods will only allow the adapter to insert binary data with a length of 7K or less
      # because of a SQL Server statement length policy.
      def string_to_binary(value)
        value.gsub(/(\r|\n|\0|\x1a)/) do
          case $1
            when "\r"
              "%00"
            when "\n"
              "%01"
            when "\0"
              "%02"
            when "\x1a"
              "%03"
          end
        end
      end

      def binary_to_string(value)
        value.gsub(/(%00|%01|%02|%03)/) do
          case $1
            when "%00"
              "\r"
            when "%01"
              "\n"
            when "%02\0"
              "\0"
            when "%03"
              "\x1a"
          end
        end
      end

    end

    class SQLServerAdapter < AbstractAdapter

      def native_database_types
        {
          :primary_key => "int NOT NULL IDENTITY(1, 1) PRIMARY KEY",
          :string      => { :name => "varchar(255)" },
          :text        => { :name => "text(16)" },
          :integer     => { :name => "int(4)", :limit => 11 },
          :float       => { :name => "float(8)" },
          :datetime    => { :name => "datetime(8)" },
          :timestamp   => { :name => "datetime(8)" },
          :time        => { :name => "datetime(8)" },
          :date        => { :name => "datetime(8)" },
          :binary      => { :name => "image(16)" },
          :boolean     => { :name => "bit(1)" }
        }
      end

      def adapter_name
        'SQLServer'
      end

      def select_all(sql, name = nil)
        add_limit!(sql, nil)
        select(sql, name)
      end

      def select_one(sql, name = nil)
        add_limit!(sql, nil)
        result = select(sql, name)
        result.nil? ? nil : result.first
      end

      def columns(table_name, name = nil)
        sql = "SELECT COLUMN_NAME as ColName, COLUMN_DEFAULT as DefaultValue, DATA_TYPE as ColType, COL_LENGTH('#{table_name}', COLUMN_NAME) as Length, COLUMNPROPERTY(OBJECT_ID('#{table_name}'), COLUMN_NAME, 'IsIdentity') as IsIdentity, NUMERIC_SCALE as Scale FROM INFORMATION_SCHEMA.columns WHERE TABLE_NAME = '#{table_name}'"
        result = nil
        # Uncomment if you want to have the Columns select statment logged.
        # Personnally, I think it adds unneccessary bloat to the log. 
        # If you do uncomment, make sure to comment the "result" line that follows
        log(sql, name, @connection) { |conn| result = conn.select_all(sql) }
        #result = @connection.select_all(sql)
        columns = []
        result.each { |field| columns << ColumnWithIdentity.new(field[:ColName], field[:DefaultValue].to_s.gsub!(/[()\']/,"") =~ /null/ ? nil : field[:DefaultValue], "#{field[:ColType]}(#{field[:Length]})", field[:IsIdentity] == 1 ? true : false, field[:Scale]) }
        columns
      end

      def insert(sql, name = nil, pk = nil, id_value = nil)
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
                # Coulnd't turn on IDENTITY_INSERT
              end
            end
          end
          log(sql, name, @connection) do |conn|
            conn.execute(sql)
            select_one("SELECT @@IDENTITY AS Ident")["Ident"]
          end
        ensure
          if ii_enabled
            begin
              execute enable_identity_insert(table_name, false)
            rescue Exception => e
              # Couldn't turn off IDENTITY_INSERT
            end
          end
        end
      end

      def execute(sql, name = nil)
        if sql =~ /^INSERT/i
          insert(sql, name)
        elsif sql =~ /^UPDATE|DELETE/i
          log(sql, name, @connection) do |conn|
            conn.execute(sql)
            retVal = select_one("SELECT @@ROWCOUNT AS AffectedRows")["AffectedRows"]
          end
        else
          log(sql, name, @connection) do |conn|
            conn.execute(sql)
          end
        end
      end

      def update(sql, name = nil)
        execute(sql, name)
      end
      alias_method :delete, :update

      def begin_db_transaction
        begin
          @connection["AutoCommit"] = false
        rescue Exception => e
          @connection["AutoCommit"] = true
        end
      end

      def commit_db_transaction
        begin
          @connection.commit
        ensure
          @connection["AutoCommit"] = true
        end
      end

      def rollback_db_transaction
        begin
          @connection.rollback
        ensure
          @connection["AutoCommit"] = true
        end
      end

      def quote(value, column = nil)
        case value
          when String                
            if column && column.type == :binary
              "'#{quote_string(column.string_to_binary(value))}'"
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

      def quote_string(s)
        s.gsub(/\'/, "''")
      end

      def quote_column_name(name)
        "[#{name}]"
      end

      def add_limit_with_offset!(sql, limit, offset)
        order_by = sql.include?("ORDER BY") ? get_order_by(sql.sub(/.*ORDER\sBY./, "")) : nil
        sql.gsub!(/SELECT/i, "SELECT * FROM ( SELECT TOP #{limit} * FROM ( SELECT TOP #{limit + offset}")<<" ) AS tmp1 ORDER BY #{order_by[1]} ) AS tmp2 ORDER BY #{order_by[0]}"
      end

      def add_limit_without_offset!(sql, limit)
        limit.nil? ? sql : sql.gsub!(/SELECT/i, "SELECT TOP #{limit}")
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

      private
        def select(sql, name = nil)
          rows = []
          log(sql, name, @connection) do |conn|
            conn.select_all(sql) do |row|
              record = {}
              row.column_names.each do |col|
                record[col] = row[col]
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
          if sql =~ /into\s*([^\s]+)\s*/i or
              sql =~ /update\s*([^\s]+)\s*/i
            $1
          else
            nil
          end
        end

        def has_identity_column(table_name)
          return get_identity_column(table_name) != nil
        end

        def get_identity_column(table_name)
          if not @table_columns
            @table_columns = {}
          end

          if @table_columns[table_name] == nil
            @table_columns[table_name] = columns(table_name)
          end

          @table_columns[table_name].each do |col|
            return col.name if col.identity
          end

          return nil
        end

        def query_contains_identity_column(sql, col)
          return sql =~ /[\[.,]\s*#{col}/
        end

        def get_order_by(sql)
          return sql, sql.gsub(/\s*DESC\s*/, "").gsub(/\s*ASC\s*/, " DESC")
        end

        def get_offset_amount(limit)
          limit = limit.gsub!(/.OFFSET./i, ",").split(',')
          return limit[0].to_i, limit[0].to_i+limit[1].to_i
        end
    end
  end
end