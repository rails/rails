module Arel
  module Predicates
    class Predicate < Struct.new(:children)
      def or(other_predicate)
        Or.new(self, other_predicate)
      end

      def and(other_predicate)
        And.new(self, other_predicate)
      end

      def complement
        Not.new(self)
      end

      def not
        self.complement
      end

      def == other
        super || (self.class === other && children == other.children)
      end
    end

    class Polyadic < Predicate
      alias :predicates :children

      def initialize(*predicates)
        super(predicates)
      end

      # Build a Polyadic predicate based on:
      # * <tt>operator</tt> - The Predicate subclass that defines the type of operation
      #   (LessThan, Equality, etc)
      # * <tt>operand1</tt> - The left-hand operand (normally an Arel::Attribute)
      # * <tt>additional_operands</tt> - All possible right-hand operands
      def self.build(operator, operand1, *additional_operands)
        new(
          *additional_operands.uniq.inject([]) do |predicates, operand|
            predicates << operator.new(operand1, operand)
          end
        )
      end

      def bind(relation)
        self.class.new(
          *predicates.map {|p| p.find_correlate_in(relation)}
        )
      end
    end

    class Any < Polyadic
      def complement
        All.new(*predicates.map {|p| p.complement})
      end
    end

    class All < Polyadic
      def complement
        Any.new(*predicates.map {|p| p.complement})
      end
    end

    class Unary < Predicate
      alias :operand :children

      def bind(relation)
        self.class.new(operand.find_correlate_in(relation))
      end
    end

    class Not < Unary
      def complement
        operand
      end
    end

    class Binary < Predicate
      alias :operand1 :children
      attr_reader :operand2

      def initialize left, right
        super(left)
        @operand2 = right
      end

      def ==(other)
        super && @operand2 == other.operand2
      end

      def bind(relation)
        self.class.new(operand1.find_correlate_in(relation), operand2.find_correlate_in(relation))
      end
    end

    class CompoundPredicate < Binary; end

    class And < CompoundPredicate
      def complement
        Or.new(operand1.complement, operand2.complement)
      end
    end

    class Or < CompoundPredicate
      def complement
        And.new(operand1.complement, operand2.complement)
      end
    end

    class Equality < Binary
      def ==(other)
        Equality === other and
          ((operand1 == other.operand1 and operand2 == other.operand2) or
           (operand1 == other.operand2 and operand2 == other.operand1))
      end

      def complement
        Inequality.new(operand1, operand2)
      end
    end

    class Inequality  < Binary
      def ==(other)
        Equality === other and
          ((operand1 == other.operand1 and operand2 == other.operand2) or
           (operand1 == other.operand2 and operand2 == other.operand1))
      end

      def complement
        Equality.new(operand1, operand2)
      end
    end

    class GreaterThanOrEqualTo < Binary
      def complement
        LessThan.new(operand1, operand2)
      end
    end

    class GreaterThan < Binary
      def complement
        LessThanOrEqualTo.new(operand1, operand2)
      end
    end

    class LessThanOrEqualTo < Binary
      def complement
        GreaterThan.new(operand1, operand2)
      end
    end

    class LessThan < Binary
      def complement
        GreaterThanOrEqualTo.new(operand1, operand2)
      end
    end

    class Match < Binary
      def complement
        NotMatch.new(operand1, operand2)
      end
    end

    class NotMatch < Binary
      def complement
        Match.new(operand1, operand2)
      end
    end

    class In < Binary
      def complement
        NotIn.new(operand1, operand2)
      end
    end

    class NotIn < Binary
      def complement
        In.new(operand1, operand2)
      end
    end
  end
end
