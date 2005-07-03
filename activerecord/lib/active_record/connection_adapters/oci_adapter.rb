# Implementation notes:
# 1.  I had to redefine a method in ActiveRecord to make it possible to implement an autonumbering
#     solution for oracle. It's implemented in a way that is intended to not break other adapters.
# 2.  Default value support needs a patch to the OCI8 driver, to enable it to read LONG columns.
#     The driver-author has said he will add this in a future release.
#     A similar patch is needed for TIMESTAMP. This should be replaced with the 0.2 version of the
#     driver, which will support TIMESTAMP properly.
# 3.  Large Object support works by an after_save callback added to the ActiveRecord. This is not
#     a problem - you can add other (chained) after_save callbacks.
# 4.  LIMIT and OFFSET now work using a select from select from select. This pattern enables
#     the middle select to limit downwards as much as possible, before the outermost select
#     limits upwards. The extra rownum column is stripped from the results.
#     See http://asktom.oracle.com/pls/ask/f?p=4950:8:::::F4950_P8_DISPLAYID:127412348064
#
# Do what you want with this code, at your own peril, but if any significant portion of my code
# remains then please acknowledge my contribution.
# Copyright 2005 Graham Jenkins
# $Revision: 1.2 $
require 'active_record/connection_adapters/abstract_adapter'

begin
  require_library_or_gem 'oci8' unless self.class.const_defined? :OCI8

  module ActiveRecord
    module ConnectionAdapters #:nodoc:
      class OCIColumn < Column #:nodoc:
        attr_reader :sql_type

        def initialize(name, default, limit, sql_type, scale)
          @name, @limit, @sql_type, @scale, @sequence = name, limit, sql_type, scale
          @type = simplified_type sql_type
          @default = type_cast default
        end

        def simplified_type(field_type)
          case field_type
          when /char/i                          : :string
          when /num|float|double|dec|real|int/i : @scale == 0 ? :integer : :float
          when /date|time/i                     : @name =~ /_at$/ ? :time : :datetime
          when /lob/i                           : :binary
          end
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

        def cast_to_date_or_time(value)
          return value if value.is_a? Date
          guess_date_or_time (value.is_a? Time) ? value : cast_to_time(value)
        end

        def cast_to_time(value)
          return value if value.is_a? Time
          time_array = ParseDate.parsedate value
          time_array[0] ||= 2000; time_array[1] ||= 1; time_array[2] ||= 1;
          Time.send Base.default_timezone, *time_array
        end

        def guess_date_or_time(value)
          (value.hour == 0 and value.min == 0 and value.sec == 0) ?
            Date.new(value.year, value.month, value.day) : value
        end
      end

      # This is an Oracle adapter for the ActiveRecord persistence framework. It relies upon the OCI8
      # driver (http://rubyforge.org/projects/ruby-oci8/), which works with Oracle 8i and above. 
      # It was developed on Windows 2000 against an 8i database, using ActiveRecord 1.6.0 and OCI8 0.1.9. 
      # It has also been tested against a 9i database.
      #
      # Usage notes:
      # * Key generation uses a sequence "rails_sequence" for all tables. (I couldn't find a simple
      #   and safe way of passing table-specific sequence information to the adapter.)
      # * Oracle uses DATE or TIMESTAMP datatypes for both dates and times. Consequently I have had to
      #   resort to some hacks to get data converted to Date or Time in Ruby.
      #   If the column_name ends in _time it's created as a Ruby Time. Else if the
      #   hours/minutes/seconds are 0, I make it a Ruby Date. Else it's a Ruby Time.
      #   This is nasty - but if you use Duck Typing you'll probably not care very much.
      #   In 9i it's tempting to map DATE to Date and TIMESTAMP to Time but I don't think that is
      #   valid - too many databases use DATE for both.
      #   Timezones and sub-second precision on timestamps are not supported.
      # * Default values that are functions (such as "SYSDATE") are not supported. This is a
      #   restriction of the way active record supports default values.
      # * Referential integrity constraints are not fully supported. Under at least
      #   some circumstances, active record appears to delete parent and child records out of
      #   sequence and out of transaction scope. (Or this may just be a problem of test setup.)
      #
      # Options:
      #
      # * <tt>:username</tt> -- Defaults to root
      # * <tt>:password</tt> -- Defaults to nothing
      # * <tt>:host</tt> -- Defaults to localhost
      class OCIAdapter < AbstractAdapter
        def quote_string(string)
          string.gsub(/'/, "''")
        end

        def quote(value, column = nil)
          if column and column.type == :binary then %Q{empty_#{ column.sql_type }()}
          else case value
            when String     then %Q{'#{quote_string(value)}'}
            when NilClass     then 'null'
            when TrueClass    then '1'
            when FalseClass   then '0'
            when Numeric    then value.to_s
            when Date, Time   then %Q{'#{value.strftime("%Y-%m-%d %H:%M:%S")}'}
            else           %Q{'#{quote_string(value.to_yaml)}'}
            end
          end
        end

        def select_all(sql, name = nil)
          offset = sql =~ /OFFSET (\d+)$/ ? $1.to_i : 0
          sql, limit = $1, $2.to_i if sql =~ /(.*)(?: LIMIT[= ](\d+))(\s*OFFSET \d+)?$/
          if limit
            sql = "select * from (select raw_sql_.*, rownum raw_rnum_ from (#{sql}) raw_sql_ where rownum <= #{offset+limit}) where raw_rnum_ > #{offset}"
          elsif offset > 0
            sql = "select * from (select raw_sql_.*, rownum raw_rnum_ from (#{sql}) raw_sql_) where raw_rnum_ > #{offset}"
          end
          cursor = log(sql, name) { @connection.exec sql }
          cols = cursor.get_col_names.map { |x| x.downcase }
          rows = []
          while row = cursor.fetch
            hash = Hash.new
            cols.each_with_index { |col, i|
              hash[col] = case row[i]
                when OCI8::LOB
                  name == 'Writable Large Object' ? row[i]: row[i].read
                when OraDate
                  (row[i].hour == 0 and row[i].minute == 0 and row[i].second == 0) ?
                    row[i].to_date : row[i].to_time
                else row[i]
                end unless col == 'raw_rnum_'
            }
            rows << hash
          end
          rows
        ensure
          cursor.close if cursor
        end

        def select_one(sql, name = nil)
          result = select_all sql, name
          result.size > 0 ? result.first : nil
        end

        def columns(table_name, name = nil)
          cols = select_all(%Q{
              select column_name, data_type, data_default, data_length, data_scale
              from user_tab_columns where table_name = '#{table_name.upcase}'}
          ).map { |row|
            OCIColumn.new row['column_name'].downcase, row['data_default'],
              row['data_length'], row['data_type'], row['data_scale']
          }
          cols
        end

        def insert(sql, name = nil, pk = nil, id_value = nil)
          if pk.nil? # Who called us? What does the sql look like? No idea!
            execute sql, name
          elsif id_value # Pre-assigned id
            log(sql, name) { @connection.exec sql }
          else # Assume the sql contains a bind-variable for the id
            id_value = select_one("select rails_sequence.nextval id from dual")['id']
            log(sql, name) { @connection.exec sql, id_value }
          end
          id_value
        end

        def execute(sql, name = nil)
          log(sql, name) { @connection.exec sql }
        end

        alias :update :execute
        alias :delete :execute

        def begin_db_transaction()
          @connection.autocommit = false
        end

        def commit_db_transaction()
          @connection.commit
        ensure
          @connection.autocommit = true
        end

        def rollback_db_transaction()
          @connection.rollback
        ensure
          @connection.autocommit = true
        end

        def adapter_name()
          'OCI'
        end
      end
    end
  end

  module ActiveRecord
    class Base
      def self.oci_connection(config) #:nodoc:
        conn = OCI8.new config[:username], config[:password], config[:host]
        conn.exec %q{alter session set nls_date_format = 'YYYY-MM-DD HH24:MI:SS'}
        conn.exec %q{alter session set nls_timestamp_format = 'YYYY-MM-DD HH24:MI:SS'}
        conn.autocommit = true
        ConnectionAdapters::OCIAdapter.new conn, logger
      end

      alias :attributes_with_quotes_pre_oci :attributes_with_quotes #:nodoc:
      # Enable the id column to be bound into the sql later, by the adapter's insert method.
      # This is preferable to inserting the hard-coded value here, because the insert method
      # needs to know the id value explicitly.
      def attributes_with_quotes(creating = true) #:nodoc:
        aq = attributes_with_quotes_pre_oci creating
        if connection.class == ConnectionAdapters::OCIAdapter
          aq[self.class.primary_key] = ":id" if creating && aq[self.class.primary_key].nil?
        end
        aq
      end

      after_save :write_lobs

      # After setting large objects to empty, select the OCI8::LOB and write back the data
      def write_lobs() #:nodoc:
        if connection.class == ConnectionAdapters::OCIAdapter
          self.class.columns.select { |c| c.type == :binary }.each { |c|
            break unless value = self[c.name]
            lob = connection.select_one(
              "select #{ c.name} from #{ self.class.table_name } WHERE #{ self.class.primary_key} = #{quote(id)}",
              'Writable Large Object'
              )[c.name]
            lob.write value
          }
        end
      end

      private :write_lobs
    end
  end

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
rescue LoadError
  # OCI8 driver is unavailable.
end
