# frozen_string_literal: true

class Object
  # Returns true if this object is included in the argument. Argument must be
  # any object which responds to +#include?+. Usage:
  #
  #   characters = ["Konata", "Kagami", "Tsukasa"]
  #   "Konata".in?(characters) # => true
  #
  # This will throw an +ArgumentError+ if the argument doesn't respond
  # to +#include?+.
  def in?(another_object)
    another_object.include?(self)
  rescue NoMethodError
    raise ArgumentError.new("The parameter passed to #in? must respond to #include?")
  end

  # Returns the receiver if it's included in the argument otherwise returns +nil+.
  # The first argument must be any object which responds to +#include?+. The second
  # optional argument is the default to return if it's not present (defaults to nil).
  # Usage:
  #
  #   params[:bucket_type].presence_in %w( project calendar )
  #
  # This will throw an +ArgumentError+ if the argument doesn't respond to +#include?+.
  #
  # Aliased to if_present_in
  #
  # @return [Object]
  def presence_in(another_object, default = nil)
    in?(another_object) ? self : default
  end
  alias_method :if_present_in, :presence_in
end
