class Object
  # Returns true if this object is excluded in the argument. Argument must be
  # any object which responds to +#include?+. Usage:
  #
  #   characters = ["Konata", "Kagami", "Tsukasa"]
  #   "MoshiMoshi".not_in?(characters) # => true
  #
  # This will throw an +ArgumentError+ if the argument doesn't respond
  # to +#include?+.
  def not_in?(another_object)
    !another_object.include?(self)
  rescue NoMethodError
    raise ArgumentError.new("The parameter passed to #not_in? must respond to #include?")
  end
end