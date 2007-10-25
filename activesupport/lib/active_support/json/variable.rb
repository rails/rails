module ActiveSupport
  module JSON
    # A string that returns itself as its JSON-encoded form.
    class Variable < String
      def to_json(options=nil)
        self
      end
    end
  end
end
