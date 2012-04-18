module ActionView
  module Helpers
    module Tags
      class DateField < TextField #:nodoc:
        def render
          options = @options.stringify_keys
          options["value"] = @options.fetch("value") { value(object).try(:to_date) }
          options["size"] = nil
          @options = options
          super
        end
      end
    end
  end
end
