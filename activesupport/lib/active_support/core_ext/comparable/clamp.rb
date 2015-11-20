module Comparable
  def clamp(min, max)
    raise ArgumentError, 'min must be less than max' unless min < max
    [self, min, max].sort[1]
  end
end