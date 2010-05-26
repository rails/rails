module Arel
  module Attributes
    class Integer < Attribute
      def type_cast(val)
        type_cast_to_numeric(val, :to_i)
      end
    end
  end
end

