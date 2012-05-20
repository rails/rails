module ActionView
  module Helpers
    module Tags
      class TimeField < TextField #:nodoc:
        def render
          options = @options.stringify_keys
          options["value"] = @options.fetch("value") { value(object).try(:strftime, "%T.%L") }
          @options = options
          super
        end
      end
    end
  end
end
