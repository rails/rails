module Enumerable
  def to_json #:nodoc:
    "[#{map { |value| ActiveSupport::JSON.encode(value) } * ', '}]"
  end
end
