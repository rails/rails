module ActiveSupport
  module JSON
    # A string that returns itself as as its JSON-encoded form.
    class Variable < String
      def to_json
        self
      end
    end
  end
end
