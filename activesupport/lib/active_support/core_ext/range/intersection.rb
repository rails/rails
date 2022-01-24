# frozen_string_literal: true

class Range
  # The maximum sized range covered by both self AND other
  # Returns nil if there is no overlap between self and other
  def intersection(other)
    unless other.is_a?(::Range)
      raise TypeError, "Can't intersect a range by a(n) #{other.class}"
    end

    if (inverted_range = [self, other].find { |r| r.inverted? })
      raise ArgumentError, "Intersection of inverted range (#{inverted_range}) is undefined"
    end

    if overlaps?(other)
      new_end = [self.end, other.end].compact.min
      # Determine the "end-exclusiveness" of the new range
      # end-exclusive is more constraining than end-inclusive so we choose end-exclusive in case of "tie"
      exclude_end = [self, other].any? { |r| r.end == new_end && r.exclude_end? }

      new_begin = [self.begin, other.begin].compact.max
      Range.new(new_begin, new_end, exclude_end)
    else
      nil
    end
  end
end
