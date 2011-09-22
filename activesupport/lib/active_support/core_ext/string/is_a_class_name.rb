class String
  # Returns true if the string is the name of a class, false otherwise.
  #
  # Examples:
  #   'String'.is_a_class_name?     # => true
  #   'Object'.is_a_class_name?     # => true
  #   'Fixnum'.is_a_class_name?     # => true
  #   'blargle'.is_a_class_name?    # => false
  #   ''.is_a_class_name?           # => false
  def is_a_class_name?
    return Module.const_get(self).is_a?(Class)
  rescue NameError
    return false
  end
end