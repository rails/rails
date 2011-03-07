module Arel
  module Attributes
    class Attribute < Struct.new :relation, :name
      include Arel::Expressions
      include Arel::Predications
      include Arel::Math
    end

    class String    < Attribute; end
    class Time      < Attribute; end
    class Boolean   < Attribute; end
    class Decimal   < Attribute; end
    class Float     < Attribute; end
    class Integer   < Attribute; end
    class Undefined < Attribute; end
  end

  Attribute = Attributes::Attribute
end
