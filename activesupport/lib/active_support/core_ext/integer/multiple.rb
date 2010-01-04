class Integer
  # Check whether the integer is evenly divisible by the argument.
  def multiple_of?(number)
    number != 0 ? self % number == 0 : zero?
  end
end
