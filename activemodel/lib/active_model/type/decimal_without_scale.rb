require "active_model/type/integer"

module ActiveModel
  module Type
    class DecimalWithoutScale < Integer # :nodoc:
      def type
        :decimal
      end
    end
  end
end
