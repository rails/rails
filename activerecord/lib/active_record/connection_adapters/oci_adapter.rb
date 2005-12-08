# oci_adapter.rb -- ActiveRecord adapter for Oracle 8i, 9i, 10g
#
# Original author: Graham Jenkins
#
# Current maintainer: Michael Schoen <schoenm@earthlink.net>
#
#########################################################################
#
# Implementation notes:
# 1. Redefines (safely) a method in ActiveRecord to make it possible to
#    implement an autonumbering solution for Oracle.
# 2. The OCI8 driver is patched to properly handle values for LONG and
#    TIMESTAMP columns. The driver-author has indicated that a future
#    release of the driver will obviate this patch.
# 3. LOB support is implemented through an after_save callback.
# 4. Oracle does not offer native LIMIT and OFFSET options; this
#    functionality is mimiced through the use of nested selects.
#    See http://asktom.oracle.com/pls/ask/f?p=4950:8:::::F4950_P8_DISPLAYID:127412348064
#
# Do what you want with this code, at your own peril, but if any
# significant portion of my code remains then please acknowledge my
# contribution.
# portions Copyright 2005 Graham Jenkins

require 'active_record/connection_adapters/abstract_adapter'
require 'delegate'

begin
  require_library_or_gem 'oci8' unless self.class.const_defined? :OCI8

  module ActiveRecord
    class Base
      def self.oci_connection(config) #:nodoc:
        # Use OCI8AutoRecover instead of normal OCI8 driver.
        ConnectionAdapters::OCIAdapter.new OCI8AutoRecover.new(config), logger
      end

      # Enable the id column to be bound into the sql later, by the adapter's insert method.
      # This is preferable to inserting the hard-coded value here, because the insert method
      # needs to know the id value explicitly.
      alias :attributes_with_quotes_pre_oci :attributes_with_quotes #:nodoc:
      def attributes_with_quotes(creating = true) #:nodoc:
        aq = attributes_with_quotes_pre_oci creating
        if connection.class == ConnectionAdapters::OCIAdapter
          aq[self.class.primary_key] = ":id" if creating && aq[self.class.primary_key].nil?
        end
        aq
      end

      # After setting large objects to empty, select the OCI8::LOB
      # and write back the data.
      after_save :write_lobs 
      def write_lobs() #:nodoc:
        if connection.is_a?(ConnectionAdapters::OCIAdapter)
          self.class.columns.select { |c| c.type == :binary }.each { |c|
            value = self[c.name]
            next if value.nil?  || (value == '')
            lob = connection.select_one(
              "select #{ c.name} from #{ self.class.table_name } WHERE #{ self.class.primary_key} = #{quote(id)}",
              'Writable Large Object')[c.name]
            lob.write value
          }
        end
      end

      private :write_lobs
    end


    module ConnectionAdapters #:nodoc:
      class OCIColumn < Column #:nodoc:
        attr_reader :sql_type

        # overridden to add the concept of scale, required to differentiate
        # between integer and float fields
        def initialize(name, default, sql_type, limit, scale, null)
          @name, @limit, @sql_type, @scale, @null = name, limit, sql_type, scale, null

          @type = simplified_type(sql_type)
          @default = type_cast(default)

          @primary = nil
          @text    = [:string, :text].include? @type
          @number  = [:float, :integer].include? @type
        end

        def type_cast(value)
          return nil if value.nil? || value =~ /^\s*null\s*$/i
          case type
          when :string   then value
          when :integer  then defined?(value.to_i) ? value.to_i : (value ? 1 : 0)
          when :float    then value.to_f
          when :datetime then cast_to_date_or_time(value)
          when :time     then cast_to_time(value)
          else value
          end
        end

        private
        def simplified_type(field_type)
          case field_type
          when /char/i                          : :string
          when /num|float|double|dec|real|int/i : @scale == 0 ? :integer : :float
          when /date|time/i                     : @name =~ /_at$/ ? :time : :datetime
          when /lob/i                           : :binary
          end
        end

        def cast_to_date_or_time(value)
          return value if value.is_a? Date
          return nil if value.blank?
          guess_date_or_time (value.is_a? Time) ? value : cast_to_time(value)
        end

        def cast_to_time(value)
          return value if value.is_a? Time
          time_array = ParseDate.parsedate value
          time_array[0] ||= 2000; time_array[1] ||= 1; time_array[2] ||= 1;
          Time.send(Base.default_timezone, *time_array) rescue nil
        end

        def guess_date_or_time(value)
          (value.hour == 0 and value.min == 0 and value.sec == 0) ?
            Date.new(value.year, value.month, value.day) : value
        end
      end


      # This is an Oracle/OCI adapter for the ActiveRecord persistence
      # framework. It relies upon the OCI8 driver, which works with Oracle 8i
      # and above. Most recent development has been on Debian Linux against
      # a 10g database, ActiveRecord 1.12.1 and OCI8 0.1.13.
      # See: http://rubyforge.org/projects/ruby-oci8/
      #
      # Usage notes:
      # * Key generation assumes a "${table_name}_seq" sequence is available
      #   for all tables; the sequence name can be changed using
      #   ActiveRecord::Base.set_sequence_name. When using Migrations, these
      #   sequences are created automatically.
      # * Oracle uses DATE or TIMESTAMP datatypes for both dates and times.
      #   Consequently some hacks are employed to map data back to Date or Time
      #   in Ruby. If the column_name ends in _time it's created as a Ruby Time.
      #   Else if the hours/minutes/seconds are 0, I make it a Ruby Date. Else
      #   it's a Ruby Time. This is a bit nasty - but if you use Duck Typing
      #   you'll probably not care very much. In 9i and up it's tempting to
      #   map DATE to Date and TIMESTAMP to Time, but too many databases use
      #   DATE for both. Timezones and sub-second precision on timestamps are
      #   not supported.
      # * Default values that are functions (such as "SYSDATE") are not
      #   supported. This is a restriction of the way ActiveRecord supports
      #   default values.
      #
      # Options:
      #
      # * <tt>:username</tt> -- Defaults to root
      # * <tt>:password</tt> -- Defaults to nothing
      # * <tt>:host</tt> -- Defaults to localhost
      class OCIAdapter < AbstractAdapter

        def adapter_name #:nodoc:
          'OCI'
        end

        def supports_migrations? #:nodoc:
          true
        end
        
        def native_database_types #:nodoc
          {
            :primary_key => "NUMBER(38) NOT NULL",
            :string      => { :name => "VARCHAR2", :limit => 255 },
            :text        => { :name => "LONG" },
            :integer     => { :name => "NUMBER", :limit => 38 },
            :float       => { :name => "NUMBER" },
            :datetime    => { :name => "DATE" },
            :timestamp   => { :name => "DATE" },
            :time        => { :name => "DATE" },
            :date        => { :name => "DATE" },
            :binary      => { :name => "BLOB" },
            :boolean     => { :name => "NUMBER", :limit => 1 }
          }
        end


        # QUOTING ==================================================
        #
        # see: abstract/quoting.rb

        # camelCase column names need to be quoted; not that anyone using Oracle
        # would really do this, but handling this case means we pass the test...
        def quote_column_name(name) #:nodoc:
          name =~ /[A-Z]/ ? "\"#{name}\"" : name
        end

        def quote_string(string) #:nodoc:
          string.gsub(/'/, "''")
        end

        def quote(value, column = nil) #:nodoc:
          if column and column.type == :binary then %Q{empty_#{ column.sql_type }()}
          else case value
            when String       then %Q{'#{quote_string(value)}'}
            when NilClass     then 'null'
            when TrueClass    then '1'
            when FalseClass   then '0'
            when Numeric      then value.to_s
            when Date, Time   then %Q{'#{value.strftime("%Y-%m-%d %H:%M:%S")}'}
            else                   %Q{'#{quote_string(value.to_yaml)}'}
            end
          end
        end


        # CONNECTION MANAGEMENT ====================================#

        # Returns true if the connection is active.
        def active?
          # Pings the connection to check if it's still good. Note that an
          # #active? method is also available, but that simply returns the 
          # last known state, which isn't good enough if the connection has
          # gone stale since the last use.
          @connection.ping
        rescue OCIError
          false
        end

        # Reconnects to the database.
        def reconnect!
          @connection.reset!
        rescue OCIError => e
          @logger.warn "#{adapter_name} automatic reconnection failed: #{e.message}"
        end


        # DATABASE STATEMENTS ======================================
        #
        # see: abstract/database_statements.rb

        def select_all(sql, name = nil) #:nodoc:
          select(sql, name)
        end

        def select_one(sql, name = nil) #:nodoc:
          result = select_all(sql, name)
          result.size > 0 ? result.first : nil
        end

        def execute(sql, name = nil) #:nodoc:
          log(sql, name) { @connection.exec sql }
        end

        def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
          if pk.nil? # Who called us? What does the sql look like? No idea!
            execute sql, name
          elsif id_value # Pre-assigned id
            log(sql, name) { @connection.exec sql }
          else # Assume the sql contains a bind-variable for the id
            id_value = select_one("select #{sequence_name}.nextval id from dual")['id']
            log(sql, name) { @connection.exec sql, id_value }
          end

          id_value
        end

        alias :update :execute #:nodoc:
        alias :delete :execute #:nodoc:

        def begin_db_transaction #:nodoc:
          @connection.autocommit = false
        end

        def commit_db_transaction #:nodoc:
          @connection.commit
        ensure
          @connection.autocommit = true
        end

        def rollback_db_transaction #:nodoc:
          @connection.rollback
        ensure
          @connection.autocommit = true
        end

        def add_limit_offset!(sql, options) #:nodoc:
          offset = options[:offset] || 0

          if limit = options[:limit]
            sql.replace "select * from (select raw_sql_.*, rownum raw_rnum_ from (#{sql}) raw_sql_ where rownum <= #{offset+limit}) where raw_rnum_ > #{offset}"
          elsif offset > 0
            sql.replace "select * from (select raw_sql_.*, rownum raw_rnum_ from (#{sql}) raw_sql_) where raw_rnum_ > #{offset}"
          end
        end

        def default_sequence_name(table, column) #:nodoc:
          "#{table}_seq"
        end


        # SCHEMA STATEMENTS ========================================
        #
        # see: abstract/schema_statements.rb

        def tables(name = nil) #:nodoc:
          select_all("select lower(table_name) from user_tables").inject([]) do | tabs, t |
            tabs << t.to_a.first.last
          end
        end

        def indexes(table_name, name = nil) #:nodoc:
          result = select_all(<<-SQL, name)
            SELECT lower(i.index_name) as index_name, i.uniqueness, lower(c.column_name) as column_name
              FROM user_indexes i, user_ind_columns c
             WHERE i.table_name = '#{table_name.to_s.upcase}'
               AND c.index_name = i.index_name
               AND i.index_name NOT IN (SELECT index_name FROM user_constraints WHERE constraint_type = 'P')
              ORDER BY i.index_name, c.column_position
          SQL

          current_index = nil
          indexes = []

          result.each do |row|
            if current_index != row['index_name']
              indexes << IndexDefinition.new(table_name, row['index_name'], row['uniqueness'] == "UNIQUE", [])
              current_index = row['index_name']
            end

            indexes.last.columns << row['column_name']
          end

          indexes
        end

        def columns(table_name, name = nil) #:nodoc:
          table_name = table_name.to_s.upcase
          owner = table_name.include?('.') ? "'#{table_name.split('.').first}'" : "user"
          table = "'#{table_name.split('.').last}'"
          scope = (owner == "user" ? "user" : "all")

          table_cols = %Q{
            select column_name, data_type, data_default, nullable,
                   decode(data_type, 'NUMBER', data_precision,
                                     'VARCHAR2', data_length,
                                      null) as length,
                   decode(data_type, 'NUMBER', data_scale, null) as scale
              from #{scope}_catalog cat, #{scope}_synonyms syn, all_tab_columns col
             where cat.table_name = #{table}
               and syn.synonym_name (+)= cat.table_name
               and col.table_name = nvl(syn.table_name, cat.table_name)
               and col.owner = nvl(syn.table_owner, #{(scope == "all" ? "cat.owner" : "user")}) }

          if scope == "all"
            table_cols << %Q{
               and cat.owner = #{owner}
               and syn.owner (+)= cat.owner }
          end

          select_all(table_cols, name).map do |row|
            row['data_default'].sub!(/^'(.*)'\s*$/, '\1') if row['data_default']
            OCIColumn.new(
              oci_downcase(row['column_name']), 
              row['data_default'],
              row['data_type'], 
              row['length'], 
              row['scale'],
              row['nullable'] == 'Y'
            )
          end
        end

        def create_table(name, options = {}) #:nodoc:
          super(name, options)
          execute "CREATE SEQUENCE #{name}_seq"
        end

        def rename_table(name, new_name) #:nodoc:
          execute "RENAME #{name} TO #{new_name}"
          execute "RENAME #{name}_seq TO #{new_name}_seq"
        end  

        def drop_table(name) #:nodoc:
          super(name)
          execute "DROP SEQUENCE #{name}_seq"
        end

        def remove_index(table_name, options = {}) #:nodoc:
          execute "DROP INDEX #{index_name(table_name, options)}"
        end

        def change_column_default(table_name, column_name, default) #:nodoc:
          execute "ALTER TABLE #{table_name} MODIFY #{column_name} DEFAULT #{quote(default)}"
        end

        def change_column(table_name, column_name, type, options = {}) #:nodoc:
          change_column_sql = "ALTER TABLE #{table_name} MODIFY #{column_name} #{type_to_sql(type, options[:limit])}"
          add_column_options!(change_column_sql, options)
          execute(change_column_sql)
        end

        def rename_column(table_name, column_name, new_column_name) #:nodoc:
          execute "ALTER TABLE #{table_name} RENAME COLUMN #{column_name} to #{new_column_name}"
        end

        def remove_column(table_name, column_name) #:nodoc:
          execute "ALTER TABLE #{table_name} DROP COLUMN #{column_name}"
        end

        def structure_dump #:nodoc:
          s = select_all("select sequence_name from user_sequences").inject("") do |structure, seq|
            structure << "create sequence #{seq.to_a.first.last};\n\n"
          end

          select_all("select table_name from user_tables").inject(s) do |structure, table|
            ddl = "create table #{table.to_a.first.last} (\n "  
            cols = select_all(%Q{
              select column_name, data_type, data_length, data_precision, data_scale, data_default, nullable
              from user_tab_columns
              where table_name = '#{table.to_a.first.last}'
              order by column_id
            }).map do |row|              
              col = "#{row['column_name'].downcase} #{row['data_type'].downcase}"      
              if row['data_type'] =='NUMBER' and !row['data_precision'].nil?
                col << "(#{row['data_precision'].to_i}"
                col << ",#{row['data_scale'].to_i}" if !row['data_scale'].nil?
                col << ')'
              elsif row['data_type'].include?('CHAR')
                col << "(#{row['data_length'].to_i})"  
              end
              col << " default #{row['data_default']}" if !row['data_default'].nil?
              col << ' not null' if row['nullable'] == 'N'
              col
            end
            ddl << cols.join(",\n ")
            ddl << ");\n\n"
            structure << ddl
          end
        end

        def structure_drop #:nodoc:
          s = select_all("select sequence_name from user_sequences").inject("") do |drop, seq|
            drop << "drop sequence #{seq.to_a.first.last};\n\n"
          end

          select_all("select table_name from user_tables").inject(s) do |drop, table|
            drop << "drop table #{table.to_a.first.last} cascade constraints;\n\n"
          end
        end


        private

        def select(sql, name = nil)
          cursor = log(sql, name) { @connection.exec sql }
          cols = cursor.get_col_names.map { |x| oci_downcase(x) }
          rows = []

          while row = cursor.fetch
            hash = Hash.new

            cols.each_with_index do |col, i|
              hash[col] =
                case row[i]
                when OCI8::LOB
                  name == 'Writable Large Object' ? row[i]: row[i].read
                when OraDate
                  (row[i].hour == 0 and row[i].minute == 0 and row[i].second == 0) ?
                  row[i].to_date : row[i].to_time
                else row[i]
                end unless col == 'raw_rnum_'
            end

            rows << hash
          end

          rows
        ensure
          cursor.close if cursor
        end

        # Oracle column names by default are case-insensitive, but treated as upcase;
        # for neatness, we'll downcase within Rails. EXCEPT that folks CAN quote
        # their column names when creating Oracle tables, which makes then case-sensitive.
        # I don't know anybody who does this, but we'll handle the theoretical case of a
        # camelCase column name. I imagine other dbs handle this different, since there's a
        # unit test that's currently failing test_oci.
        def oci_downcase(column_name)
          column_name =~ /[a-z]/ ? column_name : column_name.downcase
        end

      end
    end
  end


  # This OCI8 patch may not longer be required with the upcoming
  # release of version 0.2.
  class OCI8 #:nodoc:
    class Cursor #:nodoc:
      alias :define_a_column_pre_ar :define_a_column
      def define_a_column(i)
        case do_ocicall(@ctx) { @parms[i - 1].attrGet(OCI_ATTR_DATA_TYPE) }
        when 8    : @stmt.defineByPos(i, String, 65535) # Read LONG values
        when 187  : @stmt.defineByPos(i, OraDate) # Read TIMESTAMP values
        else define_a_column_pre_ar i
        end
      end
    end
  end


  # The OCIConnectionFactory factors out the code necessary to connect and
  # configure an OCI connection.
  class OCIConnectionFactory #:nodoc:
    def new_connection(username, password, host)
      conn = OCI8.new username, password, host
      conn.exec %q{alter session set nls_date_format = 'YYYY-MM-DD HH24:MI:SS'}
      conn.exec %q{alter session set nls_timestamp_format = 'YYYY-MM-DD HH24:MI:SS'} rescue nil
      conn.autocommit = true
      conn
    end
  end


  # The OCI8AutoRecover class enhances the OCI8 driver with auto-recover and
  # reset functionality. If a call to #exec fails, and autocommit is turned on
  # (ie., we're not in the middle of a longer transaction), it will 
  # automatically reconnect and try again. If autocommit is turned off,
  # this would be dangerous (as the earlier part of the implied transaction
  # may have failed silently if the connection died) -- so instead the 
  # connection is marked as dead, to be reconnected on it's next use.
  class OCI8AutoRecover < DelegateClass(OCI8) #:nodoc:
    attr_accessor :active
    alias :active? :active

    cattr_accessor :auto_retry
    class << self
      alias :auto_retry? :auto_retry
    end
    @@auto_retry = false

    def initialize(config, factory = OCIConnectionFactory.new)
      @active = true
      @username, @password, @host = config[:username], config[:password], config[:host]
      @factory = factory
      @connection  = @factory.new_connection @username, @password, @host
      super @connection
    end

    # Checks connection, returns true if active. Note that ping actively
    # checks the connection, while #active? simply returns the last
    # known state.
    def ping
      @connection.exec("select 1 from dual") { |r| nil }
      @active = true
    rescue
      @active = false
      raise
    end

    # Resets connection, by logging off and creating a new connection.
    def reset!
      logoff rescue nil
      begin
        @connection = @factory.new_connection @username, @password, @host
        __setobj__ @connection
        @active = true
      rescue
        @active = false
        raise
      end
    end

    # ORA-00028: your session has been killed
    # ORA-01012: not logged on 
    # ORA-03113: end-of-file on communication channel
    # ORA-03114: not connected to ORACLE
    LOST_CONNECTION_ERROR_CODES = [ 28, 1012, 3113, 3114 ]

    # Adds auto-recovery functionality.
    #
    # See: http://www.jiubao.org/ruby-oci8/api.en.html#label-11
    def exec(sql, *bindvars)
      should_retry = self.class.auto_retry? && autocommit?

      begin
        @connection.exec(sql, *bindvars)
      rescue OCIError => e
        raise unless LOST_CONNECTION_ERROR_CODES.include?(e.code)
        @active = false
        raise unless should_retry
        should_retry = false
        reset! rescue nil
        retry
      end
    end

  end

rescue LoadError
  # OCI8 driver is unavailable.
end
