class Numeric
  # Returns number limited between two numbers
  def limit(min, max)
    self > min ? (self < max ? self : max) : min
  end
end
