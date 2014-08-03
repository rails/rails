class String
  # Checks to see whether the string is a number.
  #
  #   "123".is_number?        # => true
  #   "123.45".is_number?     # => true
  #   "-123.45".is_number?    # => true
  #   "123.xx".is_number?     # => false
  def is_number?
    is_integer? || is_float?
  end

  # Checks to see whether the string is an integer.
  #
  #   "123".is_integer?       # => true
  #   "123.45".is_integer?    # => false
  #   "123xx".is_integer?     # => false
  def is_integer?
    Integer(self) rescue return false
    true
  end

  # Checks to see whether the string is a float.
  #
  #   "123.45".is_float?      # => true
  #   "123".is_float?         # => false
  #   "123.xx".is_float?      # => false
  def is_float?
    Float(self) rescue return false
    true
  end
end