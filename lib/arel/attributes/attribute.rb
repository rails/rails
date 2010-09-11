module Arel
  module Attributes
    class Attribute < Struct.new :relation, :name, :column
      def not_eq other
        Nodes::NotEqual.new self, other
      end

      def eq other
        Nodes::Equality.new self, other
      end

      def in other
        Nodes::In.new self, other
      end

      def count distinct = false
        Nodes::Count.new [self], distinct
      end

      def sum
        Nodes::Sum.new [self], Nodes::SqlLiteral.new('sum_id')
      end

      def maximum
        Nodes::Max.new [self], Nodes::SqlLiteral.new('max_id')
      end

      def minimum
        Nodes::Min.new [self], Nodes::SqlLiteral.new('min_id')
      end

      def average
        Nodes::Avg.new [self], Nodes::SqlLiteral.new('avg_id')
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
