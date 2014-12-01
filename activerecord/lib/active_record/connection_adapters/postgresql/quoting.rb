module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module Quoting
        # Escapes binary strings for bytea input to the database.
        def escape_bytea(value)
          @connection.escape_bytea(value) if value
        end

        # Unescapes bytea output from a database to the binary string it represents.
        # NOTE: This is NOT an inverse of escape_bytea! This is only to be used
        # on escaped binary output from database drive.
        def unescape_bytea(value)
          @connection.unescape_bytea(value) if value
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
          Utils.extract_schema_qualified_name(name.to_s).quoted
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

          if value.year <= 0
            bce_year = format("%04d", -value.year + 1)
            result = result.sub(/^-?\d+/, bce_year) + " BC"
          end
          result
        end

        # Does not quote function default values for UUID columns
        def quote_default_value(value, column) #:nodoc:
          if column.type == :uuid && value =~ /\(\)/
            value
          else
            quote(value, column)
          end
        end

        private

        def _quote(value)
          case value
          when Type::Binary::Data
            "'#{escape_bytea(value.to_s)}'"
          when OID::Xml::Data
            "xml '#{quote_string(value.to_s)}'"
          when OID::Bit::Data
            if value.binary?
              "B'#{value}'"
            elsif value.hex?
              "X'#{value}'"
            end
          when Float
            if value.infinite? || value.nan?
              "'#{value}'"
            else
              super
            end
          else
            super
          end
        end

        def _type_cast(value)
          case value
          when Type::Binary::Data
            # Return a bind param hash with format as binary.
            # See http://deveiate.org/code/pg/PGconn.html#method-i-exec_prepared-doc
            # for more information
            { value: value.to_s, format: 1 }
          when OID::Xml::Data, OID::Bit::Data
            value.to_s
          else
            super
          end
        end
      end
    end
  end
end
