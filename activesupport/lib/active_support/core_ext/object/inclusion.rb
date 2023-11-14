# frozen_string_literal: true

class Object
  # Returns true if this object is included in the argument.
  #
  # When argument is a +Range+, +#cover?+ is used to properly handle inclusion
  # check within open ranges. Otherwise, argument must be any object which responds
  # to +#include?+. Usage:
  #
  #   characters = ["Konata", "Kagami", "Tsukasa"]
  #   "Konata".in?(characters) # => true
  #
  # For non +Range+ arguments, this will throw an +ArgumentError+ if the argument
  # doesn't respond to +#include?+.
  #
  # As Active Record relations respond to +include?+, calling +in?+ will
  # perform a query if the relation hasn't been loaded yet:
  #
  #   mary = Person.create(name: "Mary")
  #   => #<Person id: 654, name: "Mary">
  #   mary.in?(Person.where(name: "Alice"))
  #   # SELECT 1 AS one FROM "people" WHERE "people"."name" ="Alice" ...
  #
  def in?(another_object)
    case another_object
    when Range
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
