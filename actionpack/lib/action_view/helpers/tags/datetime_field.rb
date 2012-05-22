module ActionView
  module Helpers
    module Tags
      class DatetimeField < TextField #:nodoc:
        def render
          options = @options.stringify_keys
          options["value"] = @options.fetch("value") { format_global_date_time_string(value(object)) }
          options["min"] = format_global_date_time_string(options["min"])
          options["max"] = format_global_date_time_string(options["max"])
          @options = options
          super
        end

        private

          def format_global_date_time_string(value)
            value.try(:strftime, "%Y-%m-%dT%T.%L%z")
          end
      end
    end
  end
end
