require "active_support/core_ext/string"

class Object
  # Returns true if this object is not included in the argument. Argument must be
  # any object which responds to +#include?+. Usage:
  #
  #   characters = ["Konata", "Kagami", "Tsukasa"]
  #   "Konata".not_in?(characters) # => false
  #
  # This will throw an +ArgumentError+ if the argument doesn't respond
  # to +#include?+.
  def not_in?(another_object)
    !another_object.include?(self)
  rescue NoMethodError
    raise ArgumentError.new("The parameter passed to #not_in? must respond to #include?")
  end

  # Returns the receiver if it's not included in the argument otherwise returns +nil+.
  # Argument must be any object which responds to +#include?+. Usage:
  #
  #   params[:bucket_type].absence_in %w( project calendar )
  #
  # This will throw an +ArgumentError+ if the argument doesn't respond to +#include?+.
  #
  # @return [Object]
  def absence_in(another_object)
    not_in?(another_object) ? self : nil
  end
end
