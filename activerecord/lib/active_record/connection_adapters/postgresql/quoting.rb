module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      module Quoting
        # Escapes binary strings for bytea input to the database.
        def escape_bytea(value)
          PGconn.escape_bytea(value) if value
        end

        # Unescapes bytea output from a database to the binary string it represents.
        # NOTE: This is NOT an inverse of escape_bytea! This is only to be used
        # on escaped binary output from database drive.
        def unescape_bytea(value)
          PGconn.unescape_bytea(value) if value
        end

        # Quotes PostgreSQL-specific data types for SQL input.
        def quote(value, column = nil) #:nodoc:
          return super unless column

          sql_type = type_to_sql(column.type, column.limit, column.precision, column.scale)

          case value
          when Range
            if /range$/ =~ sql_type
              "'#{PostgreSQLColumn.range_to_string(value)}'::#{sql_type}"
            else
              super
            end
          when Array
            case sql_type
            when 'point' then super(PostgreSQLColumn.point_to_string(value))
            when 'json' then super(PostgreSQLColumn.json_to_string(value))
            else
              if column.array
                "'#{PostgreSQLColumn.array_to_string(value, column, self).gsub(/'/, "''")}'"
              else
                super
              end
            end
          when Hash
            case sql_type
            when 'hstore' then super(PostgreSQLColumn.hstore_to_string(value), column)
            when 'json' then super(PostgreSQLColumn.json_to_string(value), column)
            else super
            end
          when IPAddr
            case sql_type
            when 'inet', 'cidr' then super(PostgreSQLColumn.cidr_to_string(value), column)
            else super
            end
          when Float
            if value.infinite? && column.type == :datetime
              "'#{value.to_s.downcase}'"
            elsif value.infinite? || value.nan?
              "'#{value.to_s}'"
            else
              super
            end
          when Numeric
            if sql_type == 'money' || [:string, :text].include?(column.type)
              # Not truly string input, so doesn't require (or allow) escape string syntax.
              "'#{value}'"
            else
              super
            end
          when String
            case sql_type
            when 'bytea' then "'#{escape_bytea(value)}'"
            when 'xml'   then "xml '#{quote_string(value)}'"
            when /^bit/
              case value
              when /^[01]*$/      then "B'#{value}'" # Bit-string notation
              when /^[0-9A-F]*$/i then "X'#{value}'" # Hexadecimal notation
              end
            else
              super
            end
          else
            super
          end
        end

        def type_cast(value, column, array_member = false)
          return super(value, column) unless column

          case value
          when Range
            return super(value, column) unless /range$/ =~ column.sql_type
            PostgreSQLColumn.range_to_string(value)
          when NilClass
            if column.array && array_member
              'NULL'
            elsif column.array
              value
            else
              super(value, column)
            end
          when Array
            case column.sql_type
            when 'point' then PostgreSQLColumn.point_to_string(value)
            when 'json' then PostgreSQLColumn.json_to_string(value)
            else
              return super(value, column) unless column.array
              PostgreSQLColumn.array_to_string(value, column, self)
            end
          when String
            return super(value, column) unless 'bytea' == column.sql_type
            { :value => value, :format => 1 }
          when Hash
            case column.sql_type
            when 'hstore' then PostgreSQLColumn.hstore_to_string(value, array_member)
            when 'json' then PostgreSQLColumn.json_to_string(value)
            else super(value, column)
            end
          when IPAddr
            return super(value, column) unless ['inet','cidr'].include? column.sql_type
            PostgreSQLColumn.cidr_to_string(value)
          else
            super(value, column)
          end
        end

        # Quotes strings for use in SQL input.
        def quote_string(s) #:nodoc:
          @connection.escape(s)
        end

        # Checks the following cases:
        #
        # - table_name
        # - "table.name"
        # - schema_name.table_name
        # - schema_name."table.name"
        # - "schema.name".table_name
        # - "schema.name"."table.name"
        def quote_table_name(name)
          schema, name_part = extract_pg_identifier_from_name(name.to_s)

          unless name_part
            quote_column_name(schema)
          else
            table_name, name_part = extract_pg_identifier_from_name(name_part)
            "#{quote_column_name(schema)}.#{quote_column_name(table_name)}"
          end
        end

        def quote_table_name_for_assignment(table, attr)
          quote_column_name(attr)
        end

        # Quotes column names for use in SQL queries.
        def quote_column_name(name) #:nodoc:
          PGconn.quote_ident(name.to_s)
        end

        # Quote date/time values for use in SQL input. Includes microseconds
        # if the value is a Time responding to usec.
        def quoted_date(value) #:nodoc:
          result = super
          if value.acts_like?(:time) && value.respond_to?(:usec)
            result = "#{result}.#{sprintf("%06d", value.usec)}"
          end

          if value.year < 0
            result = result.sub(/^-/, "") + " BC"
          end
          result
        end
      end
    end
  end
end
