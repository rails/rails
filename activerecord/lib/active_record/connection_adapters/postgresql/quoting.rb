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

          case value
          when Hash
            case column.sql_type
            when 'hstore' then super(PostgreSQLColumn.hstore_to_string(value), column)
            when 'json' then super(PostgreSQLColumn.json_to_string(value), column)
            else super
            end
          when IPAddr
            case column.sql_type
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
            return super unless column.sql_type == 'money'
            # Not truly string input, so doesn't require (or allow) escape string syntax.
            "'#{value}'"
          when String
            case column.sql_type
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

        def type_cast(value, column)
          return super unless column

          case value
          when String
            return super unless 'bytea' == column.sql_type
            { :value => value, :format => 1 }
          when Hash
            case column.sql_type
            when 'hstore' then PostgreSQLColumn.hstore_to_string(value)
            when 'json' then PostgreSQLColumn.json_to_string(value)
            else super
            end
          when IPAddr
            return super unless ['inet','cidr'].includes? column.sql_type
            PostgreSQLColumn.cidr_to_string(value)
          else
            super
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

        # Quotes column names for use in SQL queries.
        def quote_column_name(name) #:nodoc:
          PGconn.quote_ident(name.to_s)
        end

        # Quote date/time values for use in SQL input. Includes microseconds
        # if the value is a Time responding to usec.
        def quoted_date(value) #:nodoc:
          if value.acts_like?(:time) && value.respond_to?(:usec)
            "#{super}.#{sprintf("%06d", value.usec)}"
          else
            super
          end
        end
      end
    end
  end
end
