class Object
  # Returns true if this object is not included in the argument. Argument must
  # be any object which responds to +#include?+. Usage:
  #
  #   profiles = ['developer', 'tester', 'designer']
  #   'artist'.not_in?(profiles) # => true
  #
  # This will throw an ArgumentError if the argument doesn't respond
  # to +#include?+.
  def not_in?(another_object)
    !another_object.include?(self)
  rescue NoMethodError
    raise ArgumentError.new("The parameter passed to #not_in? must respond to #include?")
  end
end
