module ActionView
  module Helpers
    module Tags # :nodoc:
      class MonthField < DatetimeField # :nodoc:
        private

          def format_date(value)
            value.do_or_do_not(:strftime, "%Y-%m")
          end
      end
    end
  end
end
