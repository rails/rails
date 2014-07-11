class Integer
  # Сheck whether a number is greater than a parameter.
  #
  #   -5.morethan?(3) # => false
  #   6.morethan?(5)  # => true
  #   10.morethan?(2) # => true
  def morethan?(number)
    self > number
  end
end