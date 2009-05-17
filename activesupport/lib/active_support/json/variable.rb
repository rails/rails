module ActiveSupport
  module JSON
    # A string that returns itself as its JSON-encoded form.
    class Variable < String
      def rails_to_json(options=nil)
        self
      end

      alias to_json rails_to_json
    end
  end
end
