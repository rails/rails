module Arel
  module Attributes
    class Attribute < Struct.new :relation, :name
      include Arel::Expressions
      include Arel::Predications
    end

    class NumericAttribute < Attribute
      include Arel::Math
    end

    class String    < Attribute; end
    class Time      < Attribute; end
    class Boolean   < Attribute; end
    class Decimal   < NumericAttribute; end
    class Float     < NumericAttribute; end
    class Integer   < NumericAttribute; end
    class Undefined < Attribute; end
  end

  Attribute = Attributes::Attribute
end
