class Integer
  # Returns true if the number is positive.
  #
  #   1.positive?  # => true
  #   0.positive?  # => false
  #   -1.positive? # => false
  def positive?
    self > 0
  end

  # Returns true if the number is negative.
  #
  #   -1.negative? # => true
  #   0.negative?  # => false
  #   1.negative?  # => false
  def negative?
    self < 0
  end
end
