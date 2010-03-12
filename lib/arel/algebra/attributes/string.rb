module Arel
  module Attributes
    class String < Attribute
      def type_cast(value)
        return unless value
        value.to_s
      end
    end
  end
end
