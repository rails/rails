class Range
  # Limit a value to be within the range if it is outside of it, otherwise return the endpoint it is closest to
  #  (1..5).limit(9) # => 5
  #  (1..5).limit(-1) # => 1
  #  (1..5).limit(3) # => 3
  def limit(value)
    return value if cover?(value)
    if (value < self.min)
      self.min
    elsif (value > self.max)
      self.max
    end
  end
end
