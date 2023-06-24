# frozen_string_literal: true

class Range
  # Compare two ranges and see if they overlap each other
  #  (1..5).overlap?(4..6) # => true
  #  (1..5).overlap?(7..9) # => false
  def overlap?(other)
    other.begin == self.begin || cover?(other.begin) || other.cover?(self.begin)
  end

  alias :overlaps? :overlap?
end
