class Numeric
  # Checks whether the integer is evenly dividable by the argument.
  def multiple_of?(*numbers)
    zero? || numbers.all? { |n| n.nonzero? && modulo(n).zero? }
  end
end