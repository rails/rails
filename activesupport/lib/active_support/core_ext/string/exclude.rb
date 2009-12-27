class String
  # The inverse of String#include?. Returns true if the string does not include the other string.
  def exclude?(string)
    !include?(string)
  end
end
