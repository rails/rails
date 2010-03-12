module Arel
  module Attributes
    class Float < Attribute
      def type_cast(val)
        type_cast_to_numeric(val, :to_f)
      end
    end
  end
end
