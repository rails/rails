module Arel
  module Attributes
    class Attribute < Struct.new :relation, :name, :column
      def eq other
        Nodes::Equality.new self, other
      end
    end

    class String  < Attribute; end
    class Time    < Attribute; end
    class Boolean < Attribute; end
    class Decimal < Attribute; end
    class Float   < Attribute; end
    class Integer < Attribute; end
  end
end
