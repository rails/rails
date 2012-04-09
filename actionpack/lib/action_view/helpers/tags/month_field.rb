module ActionView
  module Helpers
    module Tags
      class MonthField < TextField #:nodoc:
        def render
          options = @options.stringify_keys
          options["size"] = nil
          @options = options
          super
        end
      end
    end
  end
end
