# Author: Maik Schmidt <contact@maik-schmidt.de>
require 'active_record/connection_adapters/abstract_adapter'
require 'date'

begin

  module ActiveRecord
    class Base
      # Establishes a connection to the database that's used by
      # all Active Record objects
      def self.oracle_connection(config) # :nodoc:
        require 'oracle' unless self.class.const_defined?(:ORAconn)
        symbolize_strings_in_hash(config)
        usr = config[:username] || ''
        pwd = config[:password] || ''
        db = config[:database] || ''

        connection = ORAconn.logon(usr, pwd, db)
        cursor = connection.open
        cursor.parse("ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD'")
        rows_affected = cursor.exec
        cursor.close
        ConnectionAdapters::OracleAdapter.new(connection)
      end
    end

    module ConnectionAdapters
      class OracleAdapter < AbstractAdapter
        def select_all(sql, name = nil)
          select(sql, name)
        end

        def select_one(sql, name = nil)
          select(sql, name).first
        end

        # Oracle does not support auto-generated columns, so we have to use
        # sequences. Every insert is followed by a select statement, which
        # returns the current sequence value. The statements are encapsulated
        # in an anonymous PL/SQL block (supported since Oracle 7.3) to prevent
        # race conditions and to maximize performance.
        def insert(sql, name = nil, pk = nil, id_value = nil)
          new_id = nil
          if !id_value.nil?
            execute(sql, name)
            new_id = id_value
          else
            pk_col = pk || ActiveRecord::Base::primary_key
            if sql !~ Regexp.new('\b' + pk_col + '\b')
              seq_name = sql.sub(/^\s*insert\s+?into\s+(\S+).*$/im, '\1') + "_id"
              sql.sub!(/(into\s+.*?\()/im, '\1' + "#{pk_col}, ")
              sql.sub!(/(values\s*\()/im, '\1' + "#{seq_name}.nextval, ")
              new_id = ' ' * 40 # Enough space for String representation of ID?
              log(sql, name, @connection) do |connection| 
                cursor = connection.open
                s = "begin #{sql}; select #{seq_name}.currval into :new_id from dual; end;"
                cursor.parse(s)
                cursor.bindrv(':new_id', new_id)
                cursor.exec
                cursor.close
                new_id = new_id.to_i
              end
            else
              execute(sql, name)
            end
          end
          new_id
        end

        def execute(sql, name = nil)
          rows_affected = 0
          log(sql, name, @connection) do |connection| 
            cursor = connection.open
            cursor.parse(sql)
            rows_affected = cursor.exec
            cursor.close
          end
          rows_affected
        end

        alias_method :update, :execute
        alias_method :delete, :execute

        def begin_db_transaction
          @connection.commitoff
        end

        def commit_db_transaction
          @connection.commit
          @connection.commiton
        end

        def rollback_db_transaction
          @connection.rollback
          @connection.commiton
        end

        def quote_column_name(name) name; end

        def quote(value, column = nil)
          if column && column.type == :timestamp && value.class.to_s == "String"
            begin
              value = DateTime.parse(value)
            rescue => ex
              # Value cannot be parsed.
            end
          end

          case value
          when String
            if column && column.type == :binary
              "'#{quote_string(column.string_to_binary(value))}'" # ' (for ruby-mode)
            else
              "'#{quote_string(value)}'" # ' (for ruby-mode)
            end
          when NilClass              then "NULL"
          when TrueClass             then (column && column.type == :boolean ? "'t'" : "1")
          when FalseClass            then (column && column.type == :boolean ? "'f'" : "0")
          when Float, Fixnum, Bignum then value.to_s
          when Date                  then "to_date('#{value.strftime("%Y-%m-%d")}', 'YYYY-MM-DD')" 
          when Time, DateTime        then "to_date('#{value.strftime("%Y-%m-%d %H:%M:%S")}', 'YYYY-MM-DD HH24:MI:SS')"
          else                            "'#{quote_string(value.to_yaml)}'"
          end
        end

        def quote_string(s)
          s.gsub(/'/, "''") # ' (for ruby-mode)
        end

        def add_limit!(sql, limit)
          l, o = limit.to_s.scan(/\d+/)
          if o.nil?
            sql.sub!(/^.*$/im, "select * from (#{sql}) where rownum <= #{l}")
          else
            raise ArgumentError, "LIMIT clauses with OFFSET are not supported yet!"
          end
        end

        def columns(table_name, name = nil)
          sql = <<-SQL
          select column_name,
                 data_type,
                 data_length,
                 data_precision,
                 data_default
          from   user_tab_columns
          where  table_name = upper('#{table_name}')
          SQL
          result = []
          cols = select_all(sql, name)
          cols.each do |c|
            name = c['column_name'].downcase
            default = c['data_default']
            default = (default == 'NULL') ? nil : default
            type = get_sql_type(c['data_type'], c['data_length'])
            result << Column.new(name, default, type)
          end
          result
        end

        private

        def get_sql_type(type_name, type_length)
          case type_name
          when /timestamp/i
            return "TIMESTAMP"
          when /number/i
            return "INT"
          when /date/i
            return "DATE"
          else
            return "#{type_name}(#{type_length})"
          end
        end

        def select(sql, name = nil)
          col_names = []
          cursor = nil
          log(sql, name, @connection) do |connection|
            cursor = connection.open
            col_names = parse(cursor, sql)
            cursor.exec
          end

          rows = []
          while cursor.fetch do
            row = {}
            col_names.each_with_index do |name, i|
              row[name] = cursor.getCol(i + 1)[0]
            end
            rows << row
          end
          cursor.close
          rows
        end

        VARCHAR2 = 1
        NUMBER = 2
        INTEGER = 3 ## external
        FLOAT = 4   ## external
        LONG = 8
        ROWID = 11
        DATE = 12
        RAW = 23
        LONG_RAW = 24
        UNSIGNED_INT = 68 ## external
        CHAR = 96
        MLSLABEL = 105

        def parse(cursor, sql)
          cursor.parse(sql)
          colnr = 1
          col_names = []
          loop {
            colinfo = cursor.describe(colnr)
            break if colinfo.nil?

            col_names << colinfo[2].downcase
            collength, coltype = colinfo[3], colinfo[1]

            collength, coltype = case coltype
            when NUMBER
              [40, VARCHAR2]
            when VARCHAR2, CHAR
              [(collength * 1.5).ceil, VARCHAR2]
            when LONG
              [65535, LONG]
            when LONG_RAW
              [65535, LONG_RAW]
            else
              [collength, VARCHAR2]
            end

            cursor.define(colnr, collength, coltype)
            colnr += 1
          }
          col_names
        end
      end
    end
  end
rescue LoadError
  # Oracle driver is unavailable.
end
