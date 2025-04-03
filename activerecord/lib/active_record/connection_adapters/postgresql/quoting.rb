# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module Quoting
        extend ActiveSupport::Concern

        QUOTED_COLUMN_NAMES = Concurrent::Map.new # :nodoc:
        QUOTED_TABLE_NAMES = Concurrent::Map.new # :nodoc:

        module ClassMethods # :nodoc:
          def column_name_matcher
            /
              \A
              (
                (?:
                  # "schema_name"."table_name"."column_name"::type_name | function(one or no argument)::type_name
                  ((?:\w+\.|"\w+"\.){,2}(?:\w+|"\w+")(?:::\w+)? | \w+\((?:|\g<2>)\)(?:::\w+)?)
                )
                (?:(?:\s+AS)?\s+(?:\w+|"\w+"))?
              )
              (?:\s*,\s*\g<1>)*
              \z
            /ix
          end

          def column_name_with_order_matcher
            /
              \A
              (
                (?:
                  # "schema_name"."table_name"."column_name"::type_name | function(one or no argument)::type_name
                  ((?:\w+\.|"\w+"\.){,2}(?:\w+|"\w+")(?:::\w+)? | \w+\((?:|\g<2>)\)(?:::\w+)?)
                )
                (?:\s+COLLATE\s+"\w+")?
                (?:\s+ASC|\s+DESC)?
                (?:\s+NULLS\s+(?:FIRST|LAST))?
              )
              (?:\s*,\s*\g<1>)*
              \z
            /ix
          end

          # Quotes column names for use in SQL queries.
          def quote_column_name(name) # :nodoc:
            QUOTED_COLUMN_NAMES[name] ||= PG::Connection.quote_ident(name.to_s).freeze
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
            QUOTED_TABLE_NAMES[name] ||= Utils.extract_schema_qualified_name(name.to_s).quoted.freeze
          end
        end

        class IntegerOutOf64BitRange < StandardError
          def initialize(msg)
            super(msg)
          end
        end

        # Escapes binary strings for bytea input to the database.
        def escape_bytea(value)
          valid_raw_connection.escape_bytea(value) if value
        end

        # Unescapes bytea output from a database to the binary string it represents.
        # NOTE: This is NOT an inverse of escape_bytea! This is only to be used
        # on escaped binary output from database drive.
        def unescape_bytea(value)
          valid_raw_connection.unescape_bytea(value) if value
        end

        def check_int_in_range(value)
          if value.to_int > 9223372036854775807 || value.to_int < -9223372036854775808
            exception = <<~ERROR
              Provided value outside of the range of a signed 64bit integer.

              PostgreSQL will treat the column type in question as a numeric.
              This may result in a slow sequential scan due to a comparison
              being performed between an integer or bigint value and a numeric value.

              To allow for this potentially unwanted behavior, set
              ActiveRecord.raise_int_wider_than_64bit to false.
            ERROR
            raise IntegerOutOf64BitRange.new exception
          end
        end

        def quote(value) # :nodoc:
          if ActiveRecord.raise_int_wider_than_64bit && value.is_a?(Integer)
            check_int_in_range(value)
          end

          case value
          when OID::Xml::Data
            "xml '#{quote_string(value.to_s)}'"
          when OID::Bit::Data
            if value.binary?
              "B'#{value}'"
            elsif value.hex?
              "X'#{value}'"
            end
          when Numeric
            if value.finite?
              super
            else
              "'#{value}'"
            end
          when OID::Array::Data
            quote(encode_array(value))
          when Range
            quote(encode_range(value))
          else
            super
          end
        end

        # Quotes strings for use in SQL input.
        def quote_string(s) # :nodoc:
          with_raw_connection(allow_retry: true, materialize_transactions: false) do |connection|
            connection.escape(s)
          end
        end

        def quote_table_name_for_assignment(table, attr)
          quote_column_name(attr)
        end

        # Quotes schema names for use in SQL queries.
        def quote_schema_name(schema_name)
          quote_column_name(schema_name)
        end

        # Quote date/time values for use in SQL input.
        def quoted_date(value) # :nodoc:
          if value.year <= 0
            bce_year = format("%04d", -value.year + 1)
            super.sub(/^-?\d+/, bce_year) + " BC"
          else
            super
          end
        end

        def quoted_binary(value) # :nodoc:
          "'#{escape_bytea(value.to_s)}'"
        end

        # `column` may be either an instance of Column or ColumnDefinition.
        def quote_default_expression(value, column) # :nodoc:
          if value.is_a?(Proc)
            value.call
          elsif column.type == :uuid && value.is_a?(String) && value.include?("()")
            value # Does not quote function default values for UUID columns
          elsif column.respond_to?(:array?)
            # TODO: Remove fetch_cast_type and the need for connection after we release 8.1.
            quote(column.fetch_cast_type(self).serialize(value))
          else
            super
          end
        end

        def type_cast(value) # :nodoc:
          case value
          when Type::Binary::Data
            # Return a bind param hash with format as binary.
            # See https://deveiate.org/code/pg/PG/Connection.html#method-i-exec_prepared-doc
            # for more information
            { value: value.to_s, format: 1 }
          when OID::Xml::Data, OID::Bit::Data
            value.to_s
          when OID::Array::Data
            encode_array(value)
          when Range
            encode_range(value)
          when Rational
            value.to_f
          else
            super
          end
        end

        # TODO: Make this method private after we release 8.1.
        def lookup_cast_type(sql_type) # :nodoc:
          super(query_value("SELECT #{quote(sql_type)}::regtype::oid", "SCHEMA").to_i)
        end

        private
          def encode_array(array_data)
            encoder = array_data.encoder
            values = type_cast_array(array_data.values)

            result = encoder.encode(values)
            if encoding = determine_encoding_of_strings_in_array(values)
              result.force_encoding(encoding)
            end
            result
          end

          def encode_range(range)
            "[#{type_cast_range_value(range.begin)},#{type_cast_range_value(range.end)}#{range.exclude_end? ? ')' : ']'}"
          end

          def determine_encoding_of_strings_in_array(value)
            case value
            when ::Array then determine_encoding_of_strings_in_array(value.first)
            when ::String then value.encoding
            end
          end

          def type_cast_array(values)
            case values
            when ::Array then values.map { |item| type_cast_array(item) }
            else type_cast(values)
            end
          end

          def type_cast_range_value(value)
            infinity?(value) ? "" : type_cast(value)
          end

          def infinity?(value)
            value.respond_to?(:infinite?) && value.infinite?
          end
      end
    end
  end
end
