require 'active_support/core_ext/object/truthiness'

using Truthiness

module ActiveRecord
  module Type
    class Boolean < Value # :nodoc:
      def type
        :boolean
      end

      private

      def cast_value(value)
        return nil if value == ''

        value.truthy?
      end
    end
  end
end
