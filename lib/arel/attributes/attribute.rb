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

      def eq_any others
        first = Nodes::Equality.new self, others.shift

        Nodes::Grouping.new others.inject(first) { |memo,expr|
          Nodes::Or.new(memo, Nodes::Equality.new(self, expr))
        }
      end

      def in other
        case other
        when Arel::SelectManager
          Nodes::In.new self, other.to_a.map { |x| x.id }
        when Range
          if other.exclude_end?
            left  = Nodes::GreaterThanOrEqual.new(self, other.min)
            right = Nodes::LessThan.new(self, other.max + 1)
            Nodes::And.new left, right
          else
            Nodes::Between.new(self, Nodes::And.new(other.min, other.max))
          end
        else
          Nodes::In.new self, other
        end
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
