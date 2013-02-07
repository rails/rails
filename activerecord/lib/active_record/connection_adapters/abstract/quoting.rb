require 'active_support/core_ext/big_decimal/conversions'

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module Quoting
      # Quotes the column value to help prevent
      # {SQL injection attacks}[http://en.wikipedia.org/wiki/SQL_injection].
      def quote(value, column = nil)
        # records are quoted as their primary key
        return value.quoted_id if value.respond_to?(:quoted_id)

        case value
          when String, ActiveSupport::Multibyte::Chars
            value = value.to_s
            if column && column.type == :binary && column.class.respond_to?(:string_to_binary)
              "'#{quote_string(column.class.string_to_binary(value))}'" # ' (for ruby-mode)
            elsif column && [:integer, :float].include?(column.type)
              value = column.type == :integer ? value.to_i : value.to_f
              value.to_s
            else
              "'#{quote_string(value)}'" # ' (for ruby-mode)
            end
          when NilClass                 then "NULL"
          when TrueClass, FalseClass
            if column && column.type == :integer
              value ? '1' : '0'
            elsif column && [:text, :string, :binary].include?(column.type)
              value ? "'1'" : "'0'"
            else
              value ? quoted_true : quoted_false
            end
          when Numeric, ActiveSupport::Duration
            # BigDecimals need to be output in a non-normalized form and quoted.
            value = BigDecimal === value ? value.to_s('F') : value.to_s
            if column && ![:integer, :float, :decimal].include?(column.type)
              value = "'#{value}'"
            end
            value
          when Symbol                   then "'#{quote_string(value.to_s)}'"
          else
            if value.acts_like?(:date) || value.acts_like?(:time)
              "'#{quoted_date(value)}'"
            else
              "'#{quote_string(value.to_yaml)}'"
            end
        end
      end

      # Quotes a string, escaping any ' (single quote) and \ (backslash)
      # characters.
      def quote_string(s)
        s.gsub(/\\/, '\&\&').gsub(/'/, "''") # ' (for ruby-mode)
      end

      # Quotes the column name. Defaults to no quoting.
      def quote_column_name(column_name)
        column_name
      end

      # Quotes the table name. Defaults to column name quoting.
      def quote_table_name(table_name)
        quote_column_name(table_name)
      end

      def quoted_true
        "'t'"
      end

      def quoted_false
        "'f'"
      end

      def quoted_date(value)
        if value.acts_like?(:time)
          zone_conversion_method = ActiveRecord::Base.default_timezone == :utc ? :getutc : :getlocal
          value.respond_to?(zone_conversion_method) ? value.send(zone_conversion_method) : value
        else
          value
        end.to_s(:db)
      end
    end
  end
end
