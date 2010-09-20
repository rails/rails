module Arel
  module Attributes
    class Attribute < Struct.new :relation, :name, :column
      include Arel::Expressions

      def not_eq other
        Nodes::NotEqual.new self, other
      end

      def eq other
        Nodes::Equality.new self, other
      end

      def in other
        if Arel::SelectManager === other
          other = other.to_a.map { |x| x.id }
        end
        Nodes::In.new self, other
      end

      def gteq right
        Nodes::GreaterThanOrEqual.new self, right
      end

      def gt right
        Nodes::GreaterThan.new self, right
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
