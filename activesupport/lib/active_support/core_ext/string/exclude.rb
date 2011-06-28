class String
  # The inverse of <tt>String#include?</tt>. Returns true if the string does not include the other string.
  def exclude?(string)
    !include?(string)
  end
end
