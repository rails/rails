module Arel
  module Attributes
    class Attribute < Struct.new :relation, :name, :column
      def eq other
        Nodes::Equality.new self, other
      end

      def in other
        Nodes::In.new self, other
      end

      def count
        Nodes::Count.new [self]
      end
    end

    class String  < Attribute; end
    class Time    < Attribute; end
    class Boolean < Attribute; end
    class Decimal < Attribute; end
    class Float   < Attribute; end
    class Integer < Attribute; end
  end

  Attribute = Attributes::Attribute
end
