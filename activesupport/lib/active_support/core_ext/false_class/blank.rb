class FalseClass
  # A FalseClass object is not blank.
  #
  # Object#blank? causes false values to return as blank.
  # For example, '', '   ', +nil+, [], and {} are all blank.
  #
  # This causes presence validators that use Object#blank? to return the
  # right result for boolean values containing a false value.
  def blank?
    false
  end

  # A FalseClass object is always present
  def present?
    true
  end
end