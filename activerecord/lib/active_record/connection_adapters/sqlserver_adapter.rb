require 'active_record/connection_adapters/abstract_adapter'

# sqlserver_adapter.rb -- ActiveRecord adapter for Microsoft SQL Server
#
# Author: Joey Gibson <joey@joeygibson.com>
# Date:   10/14/2004
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

      if config.has_key? :database
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

      def binary_to_string(value)
        value
      end 

      def string_to_binary(value)
        value
      end 

      def simplified_type(field_type)
        case field_type
          when /int/i
            :integer
          when /float|double|decimal|numeric/i
            if @scale == 0
              :integer
            else  
              :float
              nil
            end  
          when /datetime/i
            :datetime
          when /timestamp/i
            :timestamp
          when /time/i
            :time
          when /date/i
            :date
          when /clob|text|ntext/i
            :text
          when /blob|binary|image/i
            :binary
          when /char|string/i
            :string
          when /boolean|bit/i
            :boolean
        end
      end

      def string_to_time(string)
        return string if string.is_a?(Time)
        time_array = ParseDate.parsedate(string, true)
        time_array.each_index do |i|
          case i
            when 0
              time_array[i] = time_array[i].nil? ? "2000" : time_array[i].to_s
            when 1
              time_array[i] = time_array[i].nil? ? "Jan" : time_array[i].to_s
            when 2
              time_array[i] = time_array[i].nil? ? "1" : time_array[i].to_s
            when 3
              time_array[i] = time_array[i].nil? ? "0" : time_array[i].to_s
            when 4
              time_array[i] = time_array[i].nil? ? "0" : time_array[i].to_s
            when 5
              time_array[i] = time_array[i].nil? ? "0" : time_array[i].to_s
          end
        end
        # treat 0000-00-00 00:00:00 as nil
        Time.send(Base.default_timezone, *time_array) rescue nil
      end

    end

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
    class SQLServerAdapter < AbstractAdapter
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
        sql = <<EOL
SELECT 
COLUMN_NAME as ColName,
COLUMN_DEFAULT as DefaultValue,
DATA_TYPE as ColType,
COL_LENGTH('#{table_name}', COLUMN_NAME) as Length,
COLUMNPROPERTY(OBJECT_ID('#{table_name}'), COLUMN_NAME, 'IsIdentity') as IsIdentity,
NUMERIC_SCALE as Scale
FROM INFORMATION_SCHEMA.columns
WHERE TABLE_NAME = '#{table_name}'
EOL

        result = nil
        # Uncomment if you want to have the Columns select statment logged.
        # Personnally, I think it adds unneccessary SQL statement bloat to the log. 
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

      def update(sql, name = nil)
        execute(sql, name)
        affected_rows(name)
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
          when TrueClass             then (column && column.type == :boolean ? "'t'" : "1")
          when FalseClass            then (column && column.type == :boolean ? "'f'" : "0")
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

      def add_limit!(sql, limit)
        if sql =~ /LIMIT/i
          limit = sql.slice!(/LIMIT.*/).gsub(/LIMIT.(.*)$/, '\1')
        end
        if !limit.nil?
          limit_amount = limit.to_s.include?("OFFSET") ? get_offset_amount(limit) : Array.new([limit])
          order_by = sql.include?("ORDER BY") ? get_order_by(sql.sub(/.*ORDER\sBY./, "")) : nil
          if limit_amount.size == 2
            sql.gsub!(/SELECT/i, "SELECT * FROM ( SELECT TOP #{limit_amount[0]} * FROM ( SELECT TOP #{limit_amount[1]}")<<" ) AS tmp1 ORDER BY #{order_by[1]} ) AS tmp2 ORDER BY #{order_by[0]}"
          else
            sql.gsub!(/SELECT/i, "SELECT TOP #{limit_amount[0]}")
          end
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

      def execute(sql, name = nil)
        if sql =~ /^INSERT/i
          insert(sql, name)
        else
          log(sql, name, @connection) do |conn|
            conn.execute(sql)
          end
        end
      end

      def adapter_name()
        'SqlServer'
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
          return sql =~ /[\(\.\,]\s*#{col}/
        end

        def query_contains_text_column(sql, col)
          
        end

        def get_order_by(sql)
          return sql, sql.gsub(/\s*DESC\s*/, "").gsub(/\s*ASC\s*/, " DESC")
        end

        def get_offset_amount(limit)
          limit = limit.gsub!(/.OFFSET./i, ",").split(',')
          return limit[0].to_i, limit[0].to_i+limit[1].to_i
        end

        def affected_rows(name = nil)
          sql = "SELECT @@ROWCOUNT AS AffectedRows"
          log(sql, name, @connection) do |conn|
            conn.select_all(sql) do |row|
              return row[:AffectedRows].to_i
            end
          end
        end
    end
  end
end