module ActionView
  module Helpers
    module Tags # :nodoc:
      class DatetimeField < TextField # :nodoc:
        def render
          options = @options.stringify_keys
          options["value"] = @options.fetch("value") { format_date(value(object)) }
          options["min"] = format_date(options["min"])
          options["max"] = format_date(options["max"])
          @options = options
          super
        end

        private

          def format_date(value)
            value.try(:strftime, "%Y-%m-%dT%T.%L%z")
          end
      end
    end
  end
end
