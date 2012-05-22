module ActionView
  module Helpers
    module Tags
      class WeekField < TextField #:nodoc:
        def render
          options = @options.stringify_keys
          options["value"] = @options.fetch("value") { format_week_string(value(object)) }
          options["min"] = format_week_string(options["min"])
          options["max"] = format_week_string(options["max"])
          @options = options
          super
        end

        private

          def format_week_string(value)
            value.try(:strftime, "%Y-W%W")
          end
      end
    end
  end
end
