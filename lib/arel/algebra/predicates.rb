module Arel
  module Predicates
    class Predicate
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
    end

    class Polyadic < Predicate
      attr_reader :predicates

      def initialize(*predicates)
        @predicates = predicates
      end

      # Build a Polyadic predicate based on:
      # * <tt>operator</tt> - The Predicate subclass that defines the type of operation
      #   (LessThan, Equality, etc)
      # * <tt>operand1</tt> - The left-hand operand (normally an Arel::Attribute)
      # * <tt>additional_operands</tt> - All possible right-hand operands
      def self.build(operator, operand1, *additional_operands)
        new(
          *additional_operands.uniq.map do |operand|
            operator.new(operand1, operand)
          end
        )
      end

      def ==(other)
        super || predicates == other.predicates
      end

      def bind(relation)
        self.class.new(
          *predicates.map {|p| p.find_correlate_in(relation)}
        )
      end

      def eval(row)
        predicates.send(compounder) do |operation|
          operation.eval(row)
        end
      end

      def to_sql(formatter = nil)
        "(" +
          predicates.map {|p| p.to_sql(formatter)}.join(" #{predicate_sql} ") +
        ")"
      end
    end

    class Any < Polyadic
      def complement
        All.new(*predicates.map {|p| p.complement})
      end

      def compounder; :any? end

      def predicate_sql; "OR" end
    end

    class All < Polyadic
      def complement
        Any.new(*predicates.map {|p| p.complement})
      end

      def compounder; :all? end

      def predicate_sql; "AND" end
    end

    class Unary < Predicate
      attr_reader :operand

      def initialize operand
        @operand = operand
      end

      def bind(relation)
        self.class.new(operand.find_correlate_in(relation))
      end

      def == other
        super || self.class === other && operand == other.operand
      end

      def eval(row)
        operand.eval(row).send(operator)
      end

      def to_sql(formatter = nil)
        "#{predicate_sql} (#{operand.to_sql(formatter)})"
      end
    end

    class Not < Unary
      def complement
        operand
      end

      def eval(row)
        !operand.eval(row)
      end

      def predicate_sql; "NOT" end
    end

    class Binary < Unary
      attr_reader :operand2
      alias :operand1 :operand

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

      def eval(row)
        operand1.eval(row).send(operator, operand2.eval(row))
      end

      def to_sql(formatter = nil)
        "#{operand1.to_sql} #{predicate_sql} #{operand1.format(operand2)}"
      end
      alias :value :to_sql
    end

    class CompoundPredicate < Binary
      def eval(row)
        eval "operand1.eval(row) #{operator} operand2.eval(row)"
      end

      def to_sql(formatter = nil)
        "(#{operand1.to_sql(formatter)} #{predicate_sql} #{operand2.to_sql(formatter)})"
      end
    end

    class And < CompoundPredicate
      def complement
        Or.new(operand1.complement, operand2.complement)
      end

      def operator; :and end

      def predicate_sql; "AND" end
    end

    class Or < CompoundPredicate
      def complement
        And.new(operand1.complement, operand2.complement)
      end

      def operator; :or end

      def predicate_sql; "OR" end
    end

    class Equality < Binary
      def ==(other)
        self.class === other and
          ((operand1 == other.operand1 and operand2 == other.operand2) or
           (operand1 == other.operand2 and operand2 == other.operand1))
      end

      def complement
        Inequality.new(operand1, operand2)
      end

      def operator; :== end

      def predicate_sql
        operand2.equality_predicate_sql
      end
    end

    class Inequality < Equality
      def complement
        Equality.new(operand1, operand2)
      end

      def operator; :"!=" end
      def eval(row)
        operand1.eval(row) != operand2.eval(row)
      end

      def predicate_sql
        operand2.inequality_predicate_sql
      end
    end

    class GreaterThanOrEqualTo < Binary
      def complement
        LessThan.new(operand1, operand2)
      end

      def operator; :>= end

      def predicate_sql; '>=' end
    end

    class GreaterThan < Binary
      def complement
        LessThanOrEqualTo.new(operand1, operand2)
      end

      def operator; :> end

      def predicate_sql; '>' end
    end

    class LessThanOrEqualTo < Binary
      def complement
        GreaterThan.new(operand1, operand2)
      end

      def operator; :<= end

      def predicate_sql; '<=' end
    end

    class LessThan < Binary
      def complement
        GreaterThanOrEqualTo.new(operand1, operand2)
      end

      def operator; :< end

      def predicate_sql; '<' end
    end

    class Match < Binary
      def complement
        NotMatch.new(operand1, operand2)
      end

      def operator; :=~ end

      def predicate_sql; 'LIKE' end
    end

    class NotMatch < Binary
      def complement
        Match.new(operand1, operand2)
      end

      def eval(row)
        operand1.eval(row) !~ operand2.eval(row)
      end

      def predicate_sql; 'NOT LIKE' end
    end

    class In < Binary
      def complement
        NotIn.new(operand1, operand2)
      end

      def eval(row)
        operand2.eval(row).include?(operand1.eval(row))
      end

      def to_sql(formatter = nil)
        if operand2.is_a?(Range) && operand2.exclude_end?
          GreaterThanOrEqualTo.new(operand1, operand2.begin).and(
            LessThan.new(operand1, operand2.end)
          ).to_sql(formatter)
        else
          super
        end
      end

      def predicate_sql; operand2.inclusion_predicate_sql end
    end

    class NotIn < Binary
      def complement
        In.new(operand1, operand2)
      end

      def eval(row)
        !(operand2.eval(row).include?(operand1.eval(row)))
      end

      def predicate_sql; operand2.exclusion_predicate_sql end
    end
  end
end
