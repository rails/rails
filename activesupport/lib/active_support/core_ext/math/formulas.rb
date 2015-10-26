module Formulas

  # returns fibonacci array with specified parameter as maximum value
  def fibonacci_array(upto)
    a = [1,2]
    upto = 4_000_000
    a << a[-2] + a[-1] while a[-2] + a[-1] < upto
    a
  end

end
