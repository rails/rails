module ActionView
  module Helpers
    module Tags
      class MonthField < TextField #:nodoc:
        def render
          options = @options.stringify_keys
          options["value"] = @options.fetch("value") { format_month_string(value(object)) }
          options["min"] = format_month_string(options["min"])
          options["max"] = format_month_string(options["max"])
          @options = options
          super
        end

        private

          def format_month_string(value)
            value.try(:strftime, "%Y-%m")
          end
      end
    end
  end
end
