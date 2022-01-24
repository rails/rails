# frozen_string_literal: true

class Range
  # An inverted range is one where the beginning is greater than the end
  def inverted?
    # Since `nil` implies negative infinity at the beginning and positive infinity at the end
    # endless ranges are NOT considered inverted
    return false if [self.begin, self.end].any?(&:nil?)

    # Note we do NOT consider the special case `self.begin == self.end && exclude_end?` as inverted
    self.end < self.begin
  end
end
