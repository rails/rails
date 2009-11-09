class Integer
  # Check whether the integer is evenly divisible by the argument.
  def multiple_of?(number)
    self % number == 0
  end
end
