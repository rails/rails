class Integer
  # Returns true if the number is positive.
  #
  #   1.positive?  # => true
  #   0.positive?  # => false
  #   -1.positive? # => false
  def positive?
    self > 0
  end

  # Returns true if the number is positive.
  #
  #   -1.positive? # => true
  #   0.positive?  # => false
  #   1.positive?  # => false
  def negative?
    self < 0
  end
end
