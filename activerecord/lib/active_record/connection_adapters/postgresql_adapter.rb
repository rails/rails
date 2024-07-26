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
        port     = config[:port]     || 5432 unless host.nil?
        username = config[:username] || ""
        password = config[:password] || ""
        
        if config.has_key?(:database)
          database = config[:database]
        else
          raise ArgumentError, "No database specified. Missing argument: database."
        end

        self.connection = ConnectionAdapters::PostgreSQLAdapter.new(
          PGconn.connect(host, port, "", "", database, username, password), logger
        )
      end
    end

    module ConnectionAdapters
      class PostgreSQLAdapter < AbstractAdapter # :nodoc:

        def select_all(sql, name = nil)
          select(sql, name)
        end

        def select_one(sql, name = nil)
          result = select(sql, name)
          result.nil? ? nil : result.first
        end

        def columns(table_name, name = nil)
          table_structure(table_name).inject([]) do |columns, field|
            columns << Column.new(field[0], field[2], field[1])
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
            # This is per connection
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
            database_name = @connection.db
            schema_name, table_name = split_table_schema(table_name)
            
            # Grab a list of all the default values for the columns.
            sql =  "SELECT column_name, column_default, character_maximum_length, data_type "
            sql << "  FROM information_schema.columns "
            sql << " WHERE table_catalog = '#{database_name}' "
            sql << "   AND table_schema = '#{schema_name}' "
            sql << "   AND table_name = '#{table_name}';"

            column_defaults = nil
            log(sql, nil, @connection) { |connection| column_defaults = connection.query(sql) }
            column_defaults.collect do |row|
                field   = row[0]
                type    = type_as_string(row[3], row[2])
                default = default_value(row[1])
                length  = row[2]

                [field, type, default, length]
            end
          end

          def type_as_string(field_type, field_length)
            type = case field_type
              when 'numeric', 'real', 'money'      then 'float'
              when 'character varying', 'interval' then 'string'
              else field_type
            end

            size = field_length.nil? ? "" : "(#{field_length})"

            return type + size
          end

          def default_value(value)
            # Boolean types
            return "t" if value =~ /true/i
            return "f" if value =~ /false/i
            
            # Char/String type values
            return $1 if value =~ /^'([0-9a-zA-Z]+)'::.*/
            
            # Numeric values
            return value if value =~ /^[0-9]+(\.[0-9]*)?/
            
            # Anything else is blank, some user type, or some function
            # and we can't know the value of that, so return nil.
            return nil
          end
      end
    end
  end
rescue LoadError
  # PostgreSQL driver is not availible
end
