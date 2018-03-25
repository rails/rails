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
    if another_object.respond_to?(:include?)
      another_object.include?(self)
    else
      raise ArgumentError.new("The parameter passed to #in? must respond to #include?")
    end
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
