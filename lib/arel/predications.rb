module Arel
  module Predications
    def not_eq other
      Nodes::NotEqual.new self, Nodes.build_quoted(other, self)
    end

    def not_eq_any others
      grouping_any :not_eq, others
    end

    def not_eq_all others
      grouping_all :not_eq, others
    end

    def eq other
      Nodes::Equality.new self, Nodes.build_quoted(other, self)
    end

    def eq_any others
      grouping_any :eq, others
    end

    def eq_all others
      grouping_all :eq, others.map { |x| Nodes.build_quoted(x, self) }
    end

    def between other
      left = Nodes.build_quoted(other.begin, self)
      right = Nodes.build_quoted(other.end, self)
      Nodes::Between.new(self, left.and(right))
    end

    def in other
      case other
      when Arel::SelectManager
        Arel::Nodes::In.new(self, other.ast)
      when Range
        if other.begin == -Float::INFINITY
          if other.end == Float::INFINITY
            not_in([])
          elsif other.exclude_end?
            lt(other.end)
          else
            lteq(other.end)
          end
        elsif other.end == Float::INFINITY
          gteq(other.begin)
        elsif other.exclude_end?
          gteq(other.begin).and(lt(other.end))
        else
          between(other)
        end
      when Array
        Nodes::In.new self, other.map { |x| Nodes.build_quoted(x, self) }
      else
        Nodes::In.new self, Nodes.build_quoted(other, self)
      end
    end

    def in_any others
      grouping_any :in, others
    end

    def in_all others
      grouping_all :in, others
    end

    def not_in other
      case other
      when Arel::SelectManager
        Arel::Nodes::NotIn.new(self, other.ast)
      when Range
        if other.begin == -Float::INFINITY # The range begins with negative infinity
          if other.end == Float::INFINITY
            self.in([])
          elsif other.exclude_end?
            gteq(other.end)
          else
            gt(other.end)
          end
        elsif other.end == Float::INFINITY
          lt(other.begin)
        else
          left = lt(other.begin)
          right = if other.exclude_end?
            gteq(other.end)
          else
            gt(other.end)
          end
          left.or(right)
        end
      when Array
        Nodes::NotIn.new self, other.map { |x| Nodes.build_quoted(x, self) }
      else
        Nodes::NotIn.new self, Nodes.build_quoted(other, self)
      end
    end

    def not_in_any others
      grouping_any :not_in, others
    end

    def not_in_all others
      grouping_all :not_in, others
    end

    def matches other, escape = nil
      Nodes::Matches.new self, Nodes.build_quoted(other, self), escape
    end

    def matches_any others, escape = nil
      grouping_any :matches, others, escape
    end

    def matches_all others, escape = nil
      grouping_all :matches, others, escape
    end

    def does_not_match other, escape = nil
      Nodes::DoesNotMatch.new self, Nodes.build_quoted(other, self), escape
    end

    def does_not_match_any others, escape = nil
      grouping_any :does_not_match, others, escape
    end

    def does_not_match_all others, escape = nil
      grouping_all :does_not_match, others, escape
    end

    def gteq right
      Nodes::GreaterThanOrEqual.new self, Nodes.build_quoted(right, self)
    end

    def gteq_any others
      grouping_any :gteq, others
    end

    def gteq_all others
      grouping_all :gteq, others
    end

    def gt right
      Nodes::GreaterThan.new self, Nodes.build_quoted(right, self)
    end

    def gt_any others
      grouping_any :gt, others
    end

    def gt_all others
      grouping_all :gt, others
    end

    def lt right
      Nodes::LessThan.new self, Nodes.build_quoted(right, self)
    end

    def lt_any others
      grouping_any :lt, others
    end

    def lt_all others
      grouping_all :lt, others
    end

    def lteq right
      Nodes::LessThanOrEqual.new self, Nodes.build_quoted(right, self)
    end

    def lteq_any others
      grouping_any :lteq, others
    end

    def lteq_all others
      grouping_all :lteq, others
    end

    private

    def grouping_any method_id, others, *extras
      nodes = others.map {|expr| send(method_id, expr, *extras)}
      Nodes::Grouping.new nodes.inject { |memo,node|
        Nodes::Or.new(memo, node)
      }
    end

    def grouping_all method_id, others, *extras
      nodes = others.map {|expr| send(method_id, expr, *extras)}
      Nodes::Grouping.new Nodes::And.new(nodes)
    end
  end
end
