module ActionView
  module Helpers
    module Tags # :nodoc:
      class WeekField < DatetimeField # :nodoc:
        private

          # Returns _value_ in "2015-W41" format if _value_ responds to
          # strftime; otherwise returns nil.
          def format_date(value)
            value.try(:strftime, "%Y-W%W")
          end
      end
    end
  end
end
