module ActionView
  module Helpers
    module Tags
      class DatetimeLocalField < TextField #:nodoc:
        def render
          options = @options.stringify_keys
          options["type"] = "datetime-local"
          options["value"] = @options.fetch("value") { format_local_date_time_string(value(object)) }
          options["min"] = format_local_date_time_string(options["min"])
          options["max"] = format_local_date_time_string(options["max"])
          @options = options
          super
        end

        private

          def format_local_date_time_string(value)
            value.try(:strftime, "%Y-%m-%dT%T")
          end
      end
    end
  end
end
