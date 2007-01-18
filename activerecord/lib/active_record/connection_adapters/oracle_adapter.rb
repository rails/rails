# oracle_adapter.rb -- ActiveRecord adapter for Oracle 8i, 9i, 10g
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
      def self.oracle_connection(config) #:nodoc:
        # Use OCI8AutoRecover instead of normal OCI8 driver.
        ConnectionAdapters::OracleAdapter.new OCI8AutoRecover.new(config), logger
      end

      # for backwards-compatibility
      def self.oci_connection(config) #:nodoc:
        config[:database] = config[:host]
        self.oracle_connection(config)
      end

      # After setting large objects to empty, select the OCI8::LOB
      # and write back the data.
      after_save :write_lobs
      def write_lobs() #:nodoc:
        if connection.is_a?(ConnectionAdapters::OracleAdapter)
          self.class.columns.select { |c| c.sql_type =~ /LOB$/i }.each { |c|
            value = self[c.name]
            value = value.to_yaml if unserializable_attribute?(c.name, c)
            next if value.nil?  || (value == '')
            lob = connection.select_one(
              "SELECT #{c.name} FROM #{self.class.table_name} WHERE #{self.class.primary_key} = #{quote_value(id)}",
              'Writable Large Object')[c.name]
            lob.write value
          }
        end
      end

      private :write_lobs
    end


    module ConnectionAdapters #:nodoc:
      class OracleColumn < Column #:nodoc:

        def type_cast(value)
          return guess_date_or_time(value) if type == :datetime && OracleAdapter.emulate_dates
          super
        end

        private
        def simplified_type(field_type)
          return :boolean if OracleAdapter.emulate_booleans && field_type == 'NUMBER(1)'
          case field_type
            when /date|time/i then :datetime
            else super
          end
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
      # * Support for Oracle8 is limited by Rails' use of ANSI join syntax, which
      #   is supported in Oracle9i and later. You will need to use #finder_sql for
      #   has_and_belongs_to_many associations to run against Oracle8.
      #
      # Required parameters:
      #
      # * <tt>:username</tt>
      # * <tt>:password</tt>
      # * <tt>:database</tt>
      class OracleAdapter < AbstractAdapter

        @@emulate_booleans = true
        cattr_accessor :emulate_booleans

        @@emulate_dates = false
        cattr_accessor :emulate_dates

        def adapter_name #:nodoc:
          'Oracle'
        end

        def supports_migrations? #:nodoc:
          true
        end

        def native_database_types #:nodoc:
          {
            :primary_key => "NUMBER(38) NOT NULL PRIMARY KEY",
            :string      => { :name => "VARCHAR2", :limit => 255 },
            :text        => { :name => "CLOB" },
            :integer     => { :name => "NUMBER", :limit => 38 },
            :float       => { :name => "NUMBER" },
            :decimal     => { :name => "DECIMAL" },
            :datetime    => { :name => "DATE" },
            :timestamp   => { :name => "DATE" },
            :time        => { :name => "DATE" },
            :date        => { :name => "DATE" },
            :binary      => { :name => "BLOB" },
            :boolean     => { :name => "NUMBER", :limit => 1 }
          }
        end

        def table_alias_length
          30
        end

        # QUOTING ==================================================
        #
        # see: abstract/quoting.rb

        # camelCase column names need to be quoted; not that anyone using Oracle
        # would really do this, but handling this case means we pass the test...
        def quote_column_name(name) #:nodoc:
          name =~ /[A-Z]/ ? "\"#{name}\"" : name
        end

        def quote_string(s) #:nodoc:
          s.gsub(/'/, "''")
        end

        def quote(value, column = nil) #:nodoc:
          if column && [:text, :binary].include?(column.type)
            %Q{empty_#{ column.sql_type.downcase rescue 'blob' }()}
          else
            super
          end
        end

        def quoted_true
          "1"
        end

        def quoted_false
          "0"
        end


        # CONNECTION MANAGEMENT ====================================
        #

        # Returns true if the connection is active.
        def active?
          # Pings the connection to check if it's still good. Note that an
          # #active? method is also available, but that simply returns the
          # last known state, which isn't good enough if the connection has
          # gone stale since the last use.
          @connection.ping
        rescue OCIException
          false
        end

        # Reconnects to the database.
        def reconnect!
          @connection.reset!
        rescue OCIException => e
          @logger.warn "#{adapter_name} automatic reconnection failed: #{e.message}"
        end

        # Disconnects from the database.
        def disconnect!
          @connection.logoff rescue nil
          @connection.active = false
        end


        # DATABASE STATEMENTS ======================================
        #
        # see: abstract/database_statements.rb

        def execute(sql, name = nil) #:nodoc:
          log(sql, name) { @connection.exec sql }
        end

        # Returns the next sequence value from a sequence generator. Not generally
        # called directly; used by ActiveRecord to get the next primary key value
        # when inserting a new database record (see #prefetch_primary_key?).
        def next_sequence_value(sequence_name)
          id = 0
          @connection.exec("select #{sequence_name}.nextval id from dual") { |r| id = r[0].to_i }
          id
        end

        def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
          execute(sql, name)
          id_value
        end

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

        # Returns true for Oracle adapter (since Oracle requires primary key
        # values to be pre-fetched before insert). See also #next_sequence_value.
        def prefetch_primary_key?(table_name = nil)
          true
        end

        def default_sequence_name(table, column) #:nodoc:
          "#{table}_seq"
        end


        # SCHEMA STATEMENTS ========================================
        #
        # see: abstract/schema_statements.rb

        def current_database #:nodoc:
          select_one("select sys_context('userenv','db_name') db from dual")["db"]
        end

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
               AND i.index_name NOT IN (SELECT uc.index_name FROM user_constraints uc WHERE uc.constraint_type = 'P')
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
          (owner, table_name) = @connection.describe(table_name)

          table_cols = <<-SQL
            select column_name as name, data_type as sql_type, data_default, nullable,
                   decode(data_type, 'NUMBER', data_precision,
                                     'FLOAT', data_precision,
                                     'VARCHAR2', data_length,
                                      null) as limit,
                   decode(data_type, 'NUMBER', data_scale, null) as scale
              from all_tab_columns
             where owner      = '#{owner}'
               and table_name = '#{table_name}'
             order by column_id
          SQL

          select_all(table_cols, name).map do |row|
            limit, scale = row['limit'], row['scale']
            if limit || scale
              row['sql_type'] << "(#{(limit || 38).to_i}" + ((scale = scale.to_i) > 0 ? ",#{scale})" : ")")
            end

            # clean up odd default spacing from Oracle
            if row['data_default']
              row['data_default'].sub!(/^(.*?)\s*$/, '\1')
              row['data_default'].sub!(/^'(.*)'$/, '\1')
              row['data_default'] = nil if row['data_default'] =~ /^null$/i
            end

            OracleColumn.new(oracle_downcase(row['name']),
                             row['data_default'],
                             row['sql_type'],
                             row['nullable'] == 'Y')
          end
        end

        def create_table(name, options = {}) #:nodoc:
          super(name, options)
          seq_name = options[:sequence_name] || "#{name}_seq"
          execute "CREATE SEQUENCE #{seq_name} START WITH 10000" unless options[:id] == false
        end

        def rename_table(name, new_name) #:nodoc:
          execute "RENAME #{name} TO #{new_name}"
          execute "RENAME #{name}_seq TO #{new_name}_seq" rescue nil
        end

        def drop_table(name, options = {}) #:nodoc:
          super(name)
          seq_name = options[:sequence_name] || "#{name}_seq"
          execute "DROP SEQUENCE #{seq_name}" rescue nil
        end

        def remove_index(table_name, options = {}) #:nodoc:
          execute "DROP INDEX #{index_name(table_name, options)}"
        end

        def change_column_default(table_name, column_name, default) #:nodoc:
          execute "ALTER TABLE #{table_name} MODIFY #{column_name} DEFAULT #{quote(default)}"
        end

        def change_column(table_name, column_name, type, options = {}) #:nodoc:
          change_column_sql = "ALTER TABLE #{table_name} MODIFY #{column_name} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
          add_column_options!(change_column_sql, options)
          execute(change_column_sql)
        end

        def rename_column(table_name, column_name, new_column_name) #:nodoc:
          execute "ALTER TABLE #{table_name} RENAME COLUMN #{column_name} to #{new_column_name}"
        end

        def remove_column(table_name, column_name) #:nodoc:
          execute "ALTER TABLE #{table_name} DROP COLUMN #{column_name}"
        end

        # Find a table's primary key and sequence. 
        # *Note*: Only primary key is implemented - sequence will be nil.
        def pk_and_sequence_for(table_name)
          (owner, table_name) = @connection.describe(table_name)

          pks = select_values(<<-SQL, 'Primary Key')
            select cc.column_name
              from all_constraints c, all_cons_columns cc
             where c.owner = '#{owner}'
               and c.table_name = '#{table_name}'
               and c.constraint_type = 'P'
               and cc.owner = c.owner
               and cc.constraint_name = c.constraint_name
          SQL

          # only support single column keys
          pks.size == 1 ? [oracle_downcase(pks.first), nil] : nil
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

        # SELECT DISTINCT clause for a given set of columns and a given ORDER BY clause.
        #
        # Oracle requires the ORDER BY columns to be in the SELECT list for DISTINCT
        # queries. However, with those columns included in the SELECT DISTINCT list, you
        # won't actually get a distinct list of the column you want (presuming the column
        # has duplicates with multiple values for the ordered-by columns. So we use the 
        # FIRST_VALUE function to get a single (first) value for each column, effectively
        # making every row the same.
        #
        #   distinct("posts.id", "posts.created_at desc")
        def distinct(columns, order_by)
          return "DISTINCT #{columns}" if order_by.blank?

          # construct a valid DISTINCT clause, ie. one that includes the ORDER BY columns, using
          # FIRST_VALUE such that the inclusion of these columns doesn't invalidate the DISTINCT
          order_columns = order_by.split(',').map { |s| s.strip }.reject(&:blank?)
          order_columns = order_columns.zip((0...order_columns.size).to_a).map do |c, i|
            "FIRST_VALUE(#{c.split.first}) OVER (PARTITION BY #{columns} ORDER BY #{c}) AS alias_#{i}__"
          end
          sql = "DISTINCT #{columns}, "
          sql << order_columns * ", "
        end

        # ORDER BY clause for the passed order option.
        # 
        # Uses column aliases as defined by #distinct.
        def add_order_by_for_association_limiting!(sql, options)
          return sql if options[:order].blank?

          order = options[:order].split(',').collect { |s| s.strip }.reject(&:blank?)
          order.map! {|s| $1 if s =~ / (.*)/}
          order = order.zip((0...order.size).to_a).map { |s,i| "alias_#{i}__ #{s}" }.join(', ')

          sql << "ORDER BY #{order}"
        end

        private

        def select(sql, name = nil)
          cursor = execute(sql, name)
          cols = cursor.get_col_names.map { |x| oracle_downcase(x) }
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
        def oracle_downcase(column_name)
          column_name =~ /[a-z]/ ? column_name : column_name.downcase
        end

      end
    end
  end


  class OCI8 #:nodoc:

    # This OCI8 patch may not longer be required with the upcoming
    # release of version 0.2.
    class Cursor #:nodoc:
      alias :define_a_column_pre_ar :define_a_column
      def define_a_column(i)
        case do_ocicall(@ctx) { @parms[i - 1].attrGet(OCI_ATTR_DATA_TYPE) }
        when 8    : @stmt.defineByPos(i, String, 65535) # Read LONG values
        when 187  : @stmt.defineByPos(i, OraDate) # Read TIMESTAMP values
        when 108
          if @parms[i - 1].attrGet(OCI_ATTR_TYPE_NAME) == 'XMLTYPE'
            @stmt.defineByPos(i, String, 65535)
          else
            raise 'unsupported datatype'
          end
        else define_a_column_pre_ar i
        end
      end
    end

    # missing constant from oci8 < 0.1.14
    OCI_PTYPE_UNK = 0 unless defined?(OCI_PTYPE_UNK)

    # Uses the describeAny OCI call to find the target owner and table_name
    # indicated by +name+, parsing through synonynms as necessary. Returns
    # an array of [owner, table_name].
    def describe(name)
      @desc ||= @@env.alloc(OCIDescribe)
      @desc.attrSet(OCI_ATTR_DESC_PUBLIC, -1) if VERSION >= '0.1.14'
      @desc.describeAny(@svc, name.to_s, OCI_PTYPE_UNK) rescue raise %Q{"DESC #{name}" failed; does it exist?}
      info = @desc.attrGet(OCI_ATTR_PARAM)

      case info.attrGet(OCI_ATTR_PTYPE)
      when OCI_PTYPE_TABLE, OCI_PTYPE_VIEW
        owner      = info.attrGet(OCI_ATTR_OBJ_SCHEMA)
        table_name = info.attrGet(OCI_ATTR_OBJ_NAME)
        [owner, table_name]
      when OCI_PTYPE_SYN
        schema = info.attrGet(OCI_ATTR_SCHEMA_NAME)
        name   = info.attrGet(OCI_ATTR_NAME)
        describe(schema + '.' + name)
      else raise %Q{"DESC #{name}" failed; not a table or view.}
      end
    end

  end


  # The OracleConnectionFactory factors out the code necessary to connect and
  # configure an Oracle/OCI connection.
  class OracleConnectionFactory #:nodoc:
    def new_connection(username, password, database, async, prefetch_rows, cursor_sharing)
      conn = OCI8.new username, password, database
      conn.exec %q{alter session set nls_date_format = 'YYYY-MM-DD HH24:MI:SS'}
      conn.exec %q{alter session set nls_timestamp_format = 'YYYY-MM-DD HH24:MI:SS'} rescue nil
      conn.autocommit = true
      conn.non_blocking = true if async
      conn.prefetch_rows = prefetch_rows
      conn.exec "alter session set cursor_sharing = #{cursor_sharing}" rescue nil
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

    def initialize(config, factory = OracleConnectionFactory.new)
      @active = true
      @username, @password, @database, = config[:username], config[:password], config[:database]
      @async = config[:allow_concurrency]
      @prefetch_rows = config[:prefetch_rows] || 100
      @cursor_sharing = config[:cursor_sharing] || 'similar'
      @factory = factory
      @connection  = @factory.new_connection @username, @password, @database, @async, @prefetch_rows, @cursor_sharing
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
        @connection = @factory.new_connection @username, @password, @database, @async, @prefetch_rows, @cursor_sharing
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
    def exec(sql, *bindvars, &block)
      should_retry = self.class.auto_retry? && autocommit?

      begin
        @connection.exec(sql, *bindvars, &block)
      rescue OCIException => e
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
  module ActiveRecord # :nodoc:
    class Base
      @@oracle_error_message = "Oracle/OCI libraries could not be loaded: #{$!.to_s}"
      def self.oracle_connection(config) # :nodoc:
        # Set up a reasonable error message
        raise LoadError, @@oracle_error_message
      end
      def self.oci_connection(config) # :nodoc:
        # Set up a reasonable error message
        raise LoadError, @@oracle_error_message
      end
    end
  end
end
