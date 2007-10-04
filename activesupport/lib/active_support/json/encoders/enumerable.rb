module Enumerable
  def to_json(options = {}) #:nodoc:
    "[#{map { |value| ActiveSupport::JSON.encode(value, options) } * ', '}]"
  end
end
