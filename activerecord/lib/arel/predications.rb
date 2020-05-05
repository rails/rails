# frozen_string_literal: true

module Arel # :nodoc: all
  module Predications
    def not_eq(other)
      Nodes::NotEqual.new self, quoted_node(other)
    end

    def eq(other)
      Nodes::Equality.new self, quoted_node(other)
    end

    def is_not_distinct_from(other)
      Nodes::IsNotDistinctFrom.new self, quoted_node(other)
    end

    def is_distinct_from(other)
      Nodes::IsDistinctFrom.new self, quoted_node(other)
    end

    def between(other)
      if unboundable?(other.begin) == 1 || unboundable?(other.end) == -1
        self.in([])
      elsif open_ended?(other.begin)
        if open_ended?(other.end)
          not_in([])
        elsif other.exclude_end?
          lt(other.end)
        else
          lteq(other.end)
        end
      elsif open_ended?(other.end)
        gteq(other.begin)
      elsif other.exclude_end?
        gteq(other.begin).and(lt(other.end))
      else
        left = quoted_node(other.begin)
        right = quoted_node(other.end)
        Nodes::Between.new(self, left.and(right))
      end
    end

    def in(other)
      case other
      when Arel::SelectManager
        Arel::Nodes::In.new(self, other.ast)
      when Enumerable
        Nodes::In.new self, quoted_array(other)
      else
        Nodes::In.new self, quoted_node(other)
      end
    end

    def not_between(other)
      if unboundable?(other.begin) == 1 || unboundable?(other.end) == -1
        not_in([])
      elsif open_ended?(other.begin)
        if open_ended?(other.end)
          self.in([])
        elsif other.exclude_end?
          gteq(other.end)
        else
          gt(other.end)
        end
      elsif open_ended?(other.end)
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
    end

    def not_in(other)
      case other
      when Arel::SelectManager
        Arel::Nodes::NotIn.new(self, other.ast)
      when Enumerable
        Nodes::NotIn.new self, quoted_array(other)
      else
        Nodes::NotIn.new self, quoted_node(other)
      end
    end

    def matches(other, escape = nil, case_sensitive = false)
      Nodes::Matches.new self, quoted_node(other), escape, case_sensitive
    end

    def matches_regexp(other, case_sensitive = true)
      Nodes::Regexp.new self, quoted_node(other), case_sensitive
    end

    def does_not_match(other, escape = nil, case_sensitive = false)
      Nodes::DoesNotMatch.new self, quoted_node(other), escape, case_sensitive
    end

    def does_not_match_regexp(other, case_sensitive = true)
      Nodes::NotRegexp.new self, quoted_node(other), case_sensitive
    end

    def gteq(right)
      Nodes::GreaterThanOrEqual.new self, quoted_node(right)
    end

    def gt(right)
      Nodes::GreaterThan.new self, quoted_node(right)
    end

    def lt(right)
      Nodes::LessThan.new self, quoted_node(right)
    end

    def lteq(right)
      Nodes::LessThanOrEqual.new self, quoted_node(right)
    end

    def when(right)
      Nodes::Case.new(self).when quoted_node(right)
    end

    def concat(other)
      Nodes::Concat.new self, other
    end

    def contains(other)
      Arel::Nodes::Contains.new(self, other)
    end

    def overlaps(other)
      Arel::Nodes::Overlaps.new(self, other)
    end

    def quoted_array(others)
      others.map { |v| quoted_node(v) }
    end

    private
      def quoted_node(other)
        Nodes.build_quoted(other, self)
      end

      def infinity?(value)
        value.respond_to?(:infinite?) && value.infinite?
      end

      def unboundable?(value)
        value.respond_to?(:unboundable?) && value.unboundable?
      end

      def open_ended?(value)
        value.nil? || infinity?(value) || unboundable?(value)
      end
  end
end
