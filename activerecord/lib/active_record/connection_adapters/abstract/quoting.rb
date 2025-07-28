# frozen_string_literal: true

require "active_support/core_ext/big_decimal/conversions"

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    # = Active Record Connection Adapters \Quoting
    module Quoting
      extend ActiveSupport::Concern

      module ClassMethods # :nodoc:
        # Regexp for column names (with or without a table name prefix).
        # Matches the following:
        #
        #   "#{table_name}.#{column_name}"
        #   "#{column_name}"
        def column_name_matcher
          /
            \A
            (
              (?:
                # table_name.column_name | function(one or no argument)
                ((?:\w+\.)?\w+ | \w+\((?:|\g<2>)\))
              )
              (?:(?:\s+AS)?\s+\w+)?
            )
            (?:\s*,\s*\g<1>)*
            \z
          /ix
        end

        # Regexp for column names with order (with or without a table name prefix,
        # with or without various order modifiers). Matches the following:
        #
        #   "#{table_name}.#{column_name}"
        #   "#{table_name}.#{column_name} #{direction}"
        #   "#{table_name}.#{column_name} #{direction} NULLS FIRST"
        #   "#{table_name}.#{column_name} NULLS LAST"
        #   "#{column_name}"
        #   "#{column_name} #{direction}"
        #   "#{column_name} #{direction} NULLS FIRST"
        #   "#{column_name} NULLS LAST"
        def column_name_with_order_matcher
          /
            \A
            (
              (?:
                # table_name.column_name | function(one or no argument)
                ((?:\w+\.)?\w+ | \w+\((?:|\g<2>)\))
              )
              (?:\s+ASC|\s+DESC)?
              (?:\s+NULLS\s+(?:FIRST|LAST))?
            )
            (?:\s*,\s*\g<1>)*
            \z
          /ix
        end

        # Quotes the column name. Must be implemented by subclasses
        def quote_column_name(column_name)
          raise NotImplementedError
        end

        # Quotes the table name. Defaults to column name quoting.
        def quote_table_name(table_name)
          quote_column_name(table_name)
        end
      end

      # Quotes the column value to help prevent
      # {SQL injection attacks}[https://en.wikipedia.org/wiki/SQL_injection].
      def quote(value)
        case value
        when String, Symbol, ActiveSupport::Multibyte::Chars
          "'#{quote_string(value.to_s)}'"
        when true       then quoted_true
        when false      then quoted_false
        when nil        then "NULL"
        # BigDecimals need to be put in a non-normalized form and quoted.
        when BigDecimal then value.to_s("F")
        when Numeric then value.to_s
        when Type::Binary::Data then quoted_binary(value)
        when Type::Time::Value then "'#{quoted_time(value)}'"
        when Date, Time then "'#{quoted_date(value)}'"
        when Class      then "'#{value}'"
        else
          raise TypeError, "can't quote #{value.class.name}"
        end
      end

      # Cast a +value+ to a type that the database understands. For example,
      # SQLite does not understand dates, so this method will convert a Date
      # to a String.
      def type_cast(value)
        case value
        when Symbol, Type::Binary::Data, ActiveSupport::Multibyte::Chars
          value.to_s
        when true       then unquoted_true
        when false      then unquoted_false
        # BigDecimals need to be put in a non-normalized form and quoted.
        when BigDecimal then value.to_s("F")
        when nil, Numeric, String then value
        when Type::Time::Value then quoted_time(value)
        when Date, Time then quoted_date(value)
        else
          raise TypeError, "can't cast #{value.class.name}"
        end
      end

      # Cast a value to be used as a bound parameter of unknown type. For example,
      # MySQL might perform dangerous castings when comparing a string to a number,
      # so this method will cast numbers to string.
      def cast_bound_value(value) # :nodoc:
        value
      end

      # Quotes a string, escaping any ' (single quote) and \ (backslash)
      # characters.
      def quote_string(s)
        s.gsub("\\", '\&\&').gsub("'", "''") # ' (for ruby-mode)
      end

      # Quotes the column name.
      def quote_column_name(column_name)
        self.class.quote_column_name(column_name)
      end

      # Quotes the table name.
      def quote_table_name(table_name)
        self.class.quote_table_name(table_name)
      end

      # Override to return the quoted table name for assignment. Defaults to
      # table quoting.
      #
      # This works for MySQL where table.column can be used to
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
          # TODO: Remove fetch_cast_type and the need for connection after we release 8.1.
          cast_type = column.fetch_cast_type(self)
          value = cast_type.serialize(value)
          quote(value)
        end
      end

      def quoted_true
        "TRUE"
      end

      def unquoted_true
        true
      end

      def quoted_false
        "FALSE"
      end

      def unquoted_false
        false
      end

      # Quote date/time values for use in SQL input. Includes microseconds
      # if the value is a Time responding to usec.
      def quoted_date(value)
        if value.acts_like?(:time)
          if default_timezone == :utc
            value = value.getutc if !value.utc?
          else
            value = value.getlocal
          end
        end

        result = value.to_fs(:db)
        if value.respond_to?(:usec) && value.usec > 0
          result << "." << sprintf("%06d", value.usec)
        else
          result
        end
      end

      def quoted_time(value) # :nodoc:
        value = value.change(year: 2000, month: 1, day: 1)
        quoted_date(value).sub(/\A\d\d\d\d-\d\d-\d\d /, "")
      end

      def quoted_binary(value) # :nodoc:
        "'#{quote_string(value.to_s)}'"
      end

      def sanitize_as_sql_comment(value) # :nodoc:
        # Sanitize a string to appear within an SQL comment
        # For compatibility, this also surrounding "/*+", "/*", and "*/"
        # charcacters, possibly with single surrounding space.
        # Then follows that by replacing any internal "*/" or "/*" with
        # "* /" or "/ *"
        comment = value.to_s.dup
        comment.gsub!(%r{\A\s*/\*\+?\s?|\s?\*/\s*\Z}, "")
        comment.gsub!("*/", "* /")
        comment.gsub!("/*", "/ *")
        comment
      end

      def lookup_cast_type(sql_type) # :nodoc:
        # TODO: Make this method private after we release 8.1.
        type_map.lookup(sql_type)
      end

      private
        def type_casted_binds(binds)
          binds&.map do |value|
            if ActiveModel::Attribute === value
              type_cast(value.value_for_database)
            else
              type_cast(value)
            end
          end
        end
    end
  end
end
