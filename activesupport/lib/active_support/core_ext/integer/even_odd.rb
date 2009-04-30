class Integer
  # Check whether the integer is evenly divisible by the argument.
  def multiple_of?(number)
    self % number == 0
  end

  # Is the integer a multiple of 2?
  def even?
    multiple_of? 2
  end unless method_defined?(:even?)

  # Is the integer not a multiple of 2?
  def odd?
    !even?
  end unless method_defined?(:odd?)
end
