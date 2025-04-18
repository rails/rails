# frozen_string_literal: true

class Range
  # Compare two ranges and see if they overlap each other
  #  (1..5).overlap?(4..6) # => true
  #  (1..5).overlap?(7..9) # => false
  unless Range.method_defined?(:overlap?) # Ruby 3.3+
    def overlap?(other)
      raise TypeError unless other.is_a? Range

      self_begin = self.begin
      other_end = other.end
      other_excl = other.exclude_end?

      return false if _empty_range?(self_begin, other_end, other_excl)

      other_begin = other.begin
      self_end = self.end
      self_excl = self.exclude_end?

      return false if _empty_range?(other_begin, self_end, self_excl)
      return true if self_begin == other_begin

      return false if _empty_range?(self_begin, self_end, self_excl)
      return false if _empty_range?(other_begin, other_end, other_excl)

      true
    end

    private
    def _empty_range?(b, e, excl)
      return false if b.nil? || e.nil?

      comp = b <=> e
      comp.nil? || comp > 0 || (comp == 0 && excl)
    end
  end

  alias :overlaps? :overlap?
end
