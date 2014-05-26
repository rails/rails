module ActiveRecord
  module Type
    class Integer < Value # :nodoc:
      include Numeric

      def type
        :integer
      end

      def klass
        ::Fixnum
      end

      alias type_cast_for_database type_cast

      private

      def cast_value(value)
        case value
        when true, false
          ActiveSupport::Deprecation.warn(<<-WARNING.strip_heredoc)
            Typecasting of booleans on integer columns is deprecated, and will be removed in a
            future version of rails. If your database does not support boolean columns, check
            your adapter's documentation for boolean emulation.
          WARNING
          value ? 1 : 0
        else value.to_i rescue nil
        end
      end
    end
  end
end
