module Arel
  module Attributes
    class Decimal < Attribute
      def type_cast(val)
        type_cast_to_numeric(val, :to_d)
      end
    end
  end
end
