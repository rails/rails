module ActiveSupport
  module JSON
    # A string that returns itself as its JSON-encoded form.
    class Variable < String
      def as_json(options = nil) self end #:nodoc:
      def encode_json(encoder) self end #:nodoc:
    end
  end
end
