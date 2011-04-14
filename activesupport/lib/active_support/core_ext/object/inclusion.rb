class Object
  # Returns true if this object is included in the argument. Argument must be
  # any object which respond to +#include?+. Usage:
  #
  #   characters = ["Konata", "Kagami", "Tsukasa"]
  #   "Konata".in?(characters) # => true
  #
  def in?(another_object)
    raise ArgumentError.new("You must supply another object that responds to include?") unless another_object.respond_to?(:include?)
    another_object.include?(self)
  end
end
