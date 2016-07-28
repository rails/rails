require 'active_support/core_ext/big_decimal/conversions'

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module Quoting
      # Quotes the column value to help prevent
      # {SQL injection attacks}[http://en.wikipedia.org/wiki/SQL_injection].
      def quote(value, column = nil)
        # records are quoted as their primary key
        return value.quoted_id if value.respond_to?(:quoted_id)

        if column
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            Passing a column to `quote` has been deprecated. It is only used
            for type casting, which should be handled elsewhere. See
            https://github.com/rails/arel/commit/6160bfbda1d1781c3b08a33ec4955f170e95be11
            for more information.
          MSG
          value = type_cast_from_column(column, value)
        end

        _quote(value)
      end

      # Cast a +value+ to a type that the database understands. For example,
      # SQLite does not understand dates, so this method will convert a Date
      # to a String.
      def type_cast(value, column = nil)
        if value.respond_to?(:quoted_id) && value.respond_to?(:id)
          return value.id
        end

        if column
          value = type_cast_from_column(column, value)
        end

        _type_cast(value)
      rescue TypeError
        to_type = column ? " to #{column.type}" : ""
        raise TypeError, "can't cast #{value.class}#{to_type}"
      end

      # If you are having to call this function, you are likely doing something
      # wrong. The column does not have sufficient type information if the user
      # provided a custom type on the class level either explicitly (via
      # Attributes::ClassMethods#attribute) or implicitly (via
      # AttributeMethods::Serialization::ClassMethods#serialize, +time_zone_aware_attributes+).
      # In almost all cases, the sql type should only be used to change quoting behavior, when the primitive to
      # represent the type doesn't sufficiently reflect the differences
      # (varchar vs binary) for example. The type used to get this primitive
      # should have been provided before reaching the connection adapter.
      def type_cast_from_column(column, value) # :nodoc:
        if column
          type = lookup_cast_type_from_column(column)
          type.serialize(value)
        else
          value
        end
      end

      # See docs for #type_cast_from_column
      def lookup_cast_type_from_column(column) # :nodoc:
        lookup_cast_type(column.sql_type)
      end

      def fetch_type_metadata(sql_type)
        cast_type = lookup_cast_type(sql_type)
        SqlTypeMetadata.new(
          sql_type: sql_type,
          type: cast_type.type,
          limit: cast_type.limit,
          precision: cast_type.precision,
          scale: cast_type.scale,
        )
      end

      # Quotes a string, escaping any ' (single quote) and \ (backslash)
      # characters.
      def quote_string(s)
        s.gsub('\\'.freeze, '\&\&'.freeze).gsub("'".freeze, "''".freeze) # ' (for ruby-mode)
      end

      # Quotes the column name. Defaults to no quoting.
      def quote_column_name(column_name)
        column_name.to_s
      end

      # Quotes the table name. Defaults to column name quoting.
      def quote_table_name(table_name)
        quote_column_name(table_name)
      end

      # Override to return the quoted table name for assignment. Defaults to
      # table quoting.
      #
      # This works for mysql2 where table.column can be used to
      # resolve ambiguity.
      #
      # We override this in the sqlite3 and postgresql adapters to use only
      # the column name (as per syntax requirements).
      def quote_table_name_for_assignment(table, attr)
        quote_table_name("#{table}.#{attr}")
      end

      def quote_default_expression(value, column) # :nodoc:
        if value.is_a?(Proc)
          value.call
        else
          value = lookup_cast_type(column.sql_type).serialize(value)
          quote(value)
        end
      end

      def quoted_true
        "'t'".freeze
      end

      def unquoted_true
        't'.freeze
      end

      def quoted_false
        "'f'".freeze
      end

      def unquoted_false
        'f'.freeze
      end

      # Quote date/time values for use in SQL input. Includes microseconds
      # if the value is a Time responding to usec.
      def quoted_date(value)
        if value.acts_like?(:time)
          zone_conversion_method = ActiveRecord::Base.default_timezone == :utc ? :getutc : :getlocal

          if value.respond_to?(zone_conversion_method)
            value = value.send(zone_conversion_method)
          end
        end

        result = value.to_s(:db)
        if value.respond_to?(:usec) && value.usec > 0
          "#{result}.#{sprintf("%06d", value.usec)}"
        else
          result
        end
      end

      def quoted_time(value) # :nodoc:
        quoted_date(value).sub(/\A2000-01-01 /, '')
      end

      private

      def type_casted_binds(binds)
        binds.map { |attr| type_cast(attr.value_for_database) }
      end

      def types_which_need_no_typecasting
        [nil, Numeric, String]
      end

      def _quote(value)
        case value
        when String, ActiveSupport::Multibyte::Chars, Type::Binary::Data
          "'#{quote_string(value.to_s)}'"
        when true       then quoted_true
        when false      then quoted_false
        when nil        then "NULL"
        # BigDecimals need to be put in a non-normalized form and quoted.
        when BigDecimal then value.to_s('F')
        when Numeric, ActiveSupport::Duration then value.to_s
        when Type::Time::Value then "'#{quoted_time(value)}'"
        when Date, Time then "'#{quoted_date(value)}'"
        when Symbol     then "'#{quote_string(value.to_s)}'"
        when Class      then "'#{value}'"
        else raise TypeError, "can't quote #{value.class.name}"
        end
      end

      def _type_cast(value)
        case value
        when Symbol, ActiveSupport::Multibyte::Chars, Type::Binary::Data
          value.to_s
        when true       then unquoted_true
        when false      then unquoted_false
        # BigDecimals need to be put in a non-normalized form and quoted.
        when BigDecimal then value.to_s('F')
        when Type::Time::Value then quoted_time(value)
        when Date, Time then quoted_date(value)
        when *types_which_need_no_typecasting
          value
        else raise TypeError
        end
      end
    end
  end
end
