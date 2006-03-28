module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module Quoting
      # Quotes the column value to help prevent
      # {SQL injection attacks}[http://en.wikipedia.org/wiki/SQL_injection].
      def quote(value, column = nil)
        case value
          when String
            if column && column.type == :binary && column.class.respond_to?(:string_to_binary)
              "'#{quote_string(column.class.string_to_binary(value))}'" # ' (for ruby-mode)
            elsif column && [:integer, :float].include?(column.type) 
              value.to_s
            else
              "'#{quote_string(value)}'" # ' (for ruby-mode)
            end
          when NilClass              then "NULL"
          when TrueClass             then (column && column.type == :integer ? '1' : quoted_true)
          when FalseClass            then (column && column.type == :integer ? '0' : quoted_false)
          when Float, Fixnum, Bignum then value.to_s
          when Date                  then "'#{value.to_s}'"
          when Time, DateTime        then "'#{quoted_date(value)}'"
          else                            "'#{quote_string(value.to_yaml)}'"
        end
      end

      # Quotes a string, escaping any ' (single quote) and \ (backslash)
      # characters.
      def quote_string(s)
        s.gsub(/\\/, '\&\&').gsub(/'/, "''") # ' (for ruby-mode)
      end

      # Returns a quoted form of the column name.  This is highly adapter
      # specific.
      def quote_column_name(name)
        name
      end

      def quoted_true
        "'t'"
      end
      
      def quoted_false
        "'f'"
      end
      
      def quoted_date(value)
        value.strftime("%Y-%m-%d %H:%M:%S")
      end
    end
  end
end
