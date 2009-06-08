module Enumerable
  # Coerces the enumerable to an array for JSON encoding.
  def as_json(options = nil) #:nodoc:
    to_a
  end
end

class Array
  # Returns a JSON string representing the Array. +options+ are passed to each element.
  def to_json(options = nil) #:nodoc:
    "[#{map { |value| ActiveSupport::JSON.encode(value, options) } * ','}]"
  end

  def as_json(options = nil) #:nodoc:
    self
  end
end
