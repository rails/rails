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
        def quote_table_name(name) # :nodoc:
          @quoted_table_names[name] ||= Utils.extract_schema_qualified_name(name.to_s).quoted.freeze
        end

        # Quotes schema names for use in SQL queries.
        def quote_schema_name(name)
          PGconn.quote_ident(name)
        end

        def quote_table_name_for_assignment(table, attr)
          quote_column_name(attr)
        end

        # Quotes column names for use in SQL queries.
        def quote_column_name(name) # :nodoc:
          @quoted_column_names[name] ||= PGconn.quote_ident(super).freeze
        end

        # Quote date/time values for use in SQL input.
        def quoted_date(value) #:nodoc:
          if value.year <= 0
            bce_year = format("%04d", -value.year + 1)
            super.sub(/^-?\d+/, bce_year) + " BC"
          else
            super
          end
        end

        def quote_default_expression(value, column) # :nodoc:
          if value.is_a?(Proc)
            value.call
          elsif column.type == :uuid && value.include?("()")
            value # Does not quote function default values for UUID columns
          elsif column.respond_to?(:array?)
            value = type_cast_from_column(column, value)
            quote(value)
          else
            super
          end
        end

        def lookup_cast_type_from_column(column) # :nodoc:
          type_map.lookup(column.oid, column.fmod, column.sql_type)
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
