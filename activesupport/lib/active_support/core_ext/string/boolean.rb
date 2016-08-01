class String
  # Converts a string to a Boolean value.
  #
  # "true".to_boolean   #=> true
  # "1".to_boolean      #=> true
  # "t".to_boolean      #=> true
  # "false".to_boolean  #=> false
  # "f".to_boolean      #=> false
  # "0".to_boolean      #=> false
  # "foo".to_boolean    #=> ArgumentError: invalid boolean
  def to_boolean
    return true  if %w(true t 1).include?(self.downcase)
    return false if %w(false f 0).include?(self.downcase)
    raise ArgumentError.new("invalid boolean")
  end
end
