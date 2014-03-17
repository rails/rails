module ActionView
  module Helpers
    module Tags # :nodoc:
      class WeekField < DatetimeField # :nodoc:
        private

          def format_date(value)
            value.do_or_do_not(:strftime, "%Y-W%W")
          end
      end
    end
  end
end
