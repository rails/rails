# postgresql_adaptor.rb
# author: Luke Holden <lholden@cablelan.net>
# notes: Currently this adaptor does not pass the test_zero_date_fields
#        and test_zero_datetime_fields unit tests in the BasicsTest test
#        group.
#
#        This is due to the fact that, in postgresql you can not have a
#        totally zero timestamp. Instead null/nil should be used to 
#        represent no value.
#

require 'active_record/connection_adapters/abstract_adapter'
require 'parsedate'

begin
  # Only include the PostgreSQL driver if one hasn't already been loaded
  require 'postgres' unless self.class.const_defined?(:PGconn)

  module ActiveRecord
    class Base
      # Establishes a connection to the database that's used by all Active Record objects
      def self.postgresql_connection(config) # :nodoc:
        symbolize_strings_in_hash(config)
        host     = config[:host]     || "localhost"
        username = config[:username] || ""
        password = config[:password] || ""
        
        if config.has_key?(:database)
          database = config[:database]
        else
          raise ArgumentError, "No database specified. Missing argument: database."
        end

        self.connection = ConnectionAdapters::PostgreSQLAdapter.new(
          PGconn.connect(host, 5432, "", "", database, username, password), logger
        )
      end
    end

    module ConnectionAdapters
      class PostgreSQLAdapter < AbstractAdapter # :nodoc:
        # This is a list of the various internal types of PostgreSQL.
        # There may be a better place for this.
        BOOLOID			= 16   # "bool",		SQL_INTEGER
        BYTEAOID		= 17   # "bytea",		SQL_BINARY
        CHAROID			= 18   # "char",		SQL_CHAR
        NAMEOID			= 19   # "name",		SQL_VARCHAR
        INT8OID			= 20   # "int8",		SQL_DOUBLE
        INT2OID			= 21   # "int2",		SQL_SMALLINT
        INT2VECTOROID		= 22   # "int28"
        INT4OID			= 23   # "int4",		SQL_INTEGER
        REGPROCOID		= 24   # "regproc"
        TEXTOID			= 25   # "text",		SQL_VARCHAR
        OIDOID			= 26   # "oid",			SQL_INTEGER
        TIDOID			= 27   # "tid",			SQL_INTEGER
        XIDOID 			= 28   # "xid",			SQL_INTEGER
        CIDOID 			= 29   # "cid",			SQL_INTEGER
        OIDVECTOROID		= 30   # "oid8"
        POINTOID		= 600  # "point"
        LSEGOID			= 601  # "lseg"
        PATHOID			= 602  # "path"
        BOXOID			= 603  # "box"
        POLYGONOID		= 604  # "polygon"
        LINEOID			= 628  # "line"
        FLOAT4OID 		= 700  # "float4",		SQL_NUMERIC
        FLOAT8OID 		= 701  # "float8", 		SQL_REAL
        ABSTIMEOID		= 702  # "abstime"
        RELTIMEOID		= 703  # "reltime"
        TINTERVALOID		= 704  # "tinterval"
        UNKNOWNOID		= 705  # "unknown"
        CIRCLEOID		= 718  # "circle"
        CASHOID 		= 790  # "money"
        MACADDROID 		= 829  # "Mac address"
        INETOID 		= 869  # "IP address"
        CIDROID 		= 650  # "IP - cidr"
        ACLITEMOID		= 1033 # "aclitem"
        BPCHAROID		= 1042 # "bpchar",		SQL_CHAR
        VARCHAROID		= 1043 # "varchar", 		SQL_VARCHAR
        DATEOID			= 1082 # "date"
        TIMEOID			= 1083 # "time"
        TIMESTAMPOID		= 1114 # "timestamp"
        TIMESTAMPTZOID		= 1184 # "datetime"
        INTERVALOID		= 1186 # "timespan"
        TIMETZOID		= 1266 # "timestampz"
        BITOID	 		= 1560 # "bitstring"
        VARBITOID	 	= 1562 # "vbitstring"
        NUMERICOID		= 1700 # "numeric",		SQL_DECIMAL
        REFCURSOROID		= 1790 # "refcursor"
        REGPROCEDUREOID 	= 2202 # "regprocedureoid"
        REGOPEROID		= 2203 # "registerdoperator
        REGOPERATOROID		= 2204 # "registeroperator_arts
        REGCLASSOID		= 2205 # "regclass"
        REGTYPEOID		= 2206 # "regtype"
        RECORDOID		= 2249 # "record"
        CSTRINGOID		= 2275 # "cstring"
        ANYOID			= 2276 # "any"
        ANYARRAYOID		= 2277 # "anyarray"
        VOIDOID			= 2278 # "void"
        TRIGGEROID		= 2279 # "trigger"
        LANGUAGE_HANDLEROID	= 2280 # "languagehandle"
        INTERNALOID		= 2281 # "internal"
        OPAQUEOID		= 2282 # "opaque"


        def select_all(sql, name = nil)
          select(sql, name)
        end

        def select_one(sql, name = nil)
          result = select(sql, name)
          result.nil? ? nil : result.first
        end

        def columns(table_name, name = nil)
          table_structure(table_name).inject([]) do |columns, field|
            columns << Column.new(field[0], field[2], type_as_string(field[1], field[3]))
            columns
          end
        end

        def insert(sql, name = nil)
          execute(sql, name = nil)

          begin
            table = sql.split(" ", 4)[2]
            last_insert_id(table)
          rescue
            # table_id_seq not found
          end
        end

        def execute(sql, name = nil)
          log(sql, name, @connection) { |connection| connection.query(sql) }
        end

        alias_method :update, :execute
        alias_method :delete, :execute

        def begin_db_transaction()    execute "BEGIN" end
        def commit_db_transaction()   execute "COMMIT" end
        def rollback_db_transaction() execute "ROLLBACK" end


        private
          def last_insert_id(table, column = "id")
            # This would appear to be per connection... so it should be safe
            # will throw an error if the sequence does not exist... so make sure
            # to catch it.
            result = @connection.exec("SELECT currval('#{table}_#{column}_seq')");
            result[0][0].to_i
          end

          def select(sql, name = nil)
            res = nil
            log(sql, name, @connection) { |connection| res = connection.exec(sql) }
    
            results = res.result           
            rows = []
            if results.length > 0
              fields = res.fields
              results.each do |row|
                hashed_row = {}
                row.each_index { |cel_index| hashed_row[fields[cel_index]] = row[cel_index] }
                rows << hashed_row
              end
            end
            return rows
          end

          def split_table_schema(table_name)
            schema_split = table_name.split('.')
            schema_name = "public"
            if schema_split.length > 1
              schema_name = schema_split.first.strip
              table_name = schema_split.last.strip
            end
            return [schema_name, table_name]
          end

          def table_structure(table_name)
            # Due to the fact there is no way to directly get the default
            # value from a column without having to query the columns table,
            # we are forced to make two queries. However, considering we
            # are not actually asking for any data in the second query, we 
            # should not hurt TOO bad on performance.

            database_name = @connection.db
            schema_name, table_name = split_table_schema(table_name)
            
            # Grab a list of all the default values for the columns.
            sql =  "SELECT column_name, column_default, character_maximum_length "
            sql << "  FROM information_schema.columns "
            sql << " WHERE table_catalog = '#{database_name}' "
            sql << "   AND table_schema = '#{schema_name}' "
            sql << "   AND table_name = '#{table_name}';"

            column_defaults = nil
            log(sql, nil, @connection) { |connection| column_defaults = connection.query(sql) }


            # A dummy query used to get a ResultSet that we can ask type
            # information from.
            sql =  "SELECT * "
            sql << "  FROM #{schema_name}.#{table_name} "
            sql << "  LIMIT 0;"

            field_res = []
            log(sql, nil, @connection) { |connection| field_res = connection.exec(sql) }
           
            # return a new array of rows, containing arrays of column data.
            field_res.fields.collect do |field|
              index = field_res.fieldnum(field)
              type = field_res.type(index)
              default = column_defaults.find { |row| row[0] == field }[1]
              length  = column_defaults.find { |row| row[0] == field }[2]

              [field, type, default, length]
            end
          end

          def type_as_string(field_type, field_length)
            type = case field_type
              when BOOLOID
                "bool"
              when INT2OID, INT4OID, OIDOID, TIDOID, XIDOID, CIDOID, INT8OID
                "integer"
              when FLOAT4OID, FLOAT8OID, NUMERICOID, CASHOID
                "float"
              when TIMESTAMPOID, TIMETZOID, TIMESTAMPTZOID
                "timestamp"
              when INTERVALOID
                "time"
              when TIMEOID
                "time"
              when DATEOID
                "date"
              when NAMEOID, VARCHAROID, CSTRINGOID, BPCHAROID
                "string"
              when TEXTOID
                "text"
            end
            
            size = field_length.nil? ? "" : "(#{field_length})"
            return type + size
          end
      end
    end
  end
rescue LoadError
  # PostgreSQL driver is not availible
end
