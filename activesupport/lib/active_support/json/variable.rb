module ActiveSupport
  module JSON
    # A string that returns itself as its JSON-encoded form.
    class Variable < String
      private
        def rails_to_json(*)
          self
        end
    end
  end
end
