class Object
  # Returns true if this object is included in the argument. Argument must be
  # any object which respond to +#include?+. Usage:
  #
  #   characters = ["Konata", "Kagami", "Tsukasa"]
  #   "Konata".in?(characters) # => true
  #
  def in?(another_object)
    another_object.include?(self)
  end

  # Returns true if this object is included in the argument list. Usage:
  #
  #   username = "sikachu"
  #   username.either?("josevalim", "dhh", "wycats") # => false
  #
  def either?(*objects)
    objects.include?(self)
  end
end
