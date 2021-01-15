# frozen_string_literal: true

class Object
  # Returns true if this object is included in the argument. Argument must be
  # any object which responds to +#include?+ or is a +Range+. Usage:
  #
  #   characters = ["Konata", "Kagami", "Tsukasa"]
  #   "Konata".in?(characters) # => true
  #
  # In case the object is an instance of a +Range+, it will use +#cover?+.
  #
  # This will throw an +ArgumentError+ if the argument doesn't respond
  # to +#include?+ or is not a +Range+.
  def in?(another_object)
    if another_object.is_a?(Range)
      another_object.cover?(self)
    else
      another_object.include?(self)
    end
  rescue NoMethodError
    raise ArgumentError.new("The parameter passed to #in? must respond to #include?")
  end

  # Returns the receiver if it's included in the argument otherwise returns +nil+.
  # Argument must be any object which responds to +#include?+. Usage:
  #
  #   params[:bucket_type].presence_in %w( project calendar )
  #
  # This will throw an +ArgumentError+ if the argument doesn't respond to +#include?+.
  #
  # @return [Object]
  def presence_in(another_object)
    in?(another_object) ? self : nil
  end
end
