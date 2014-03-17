module ActionView
  module Helpers
    module Tags # :nodoc:
      class DateField < DatetimeField # :nodoc:
        private

          def format_date(value)
            value.do_or_do_not(:strftime, "%Y-%m-%d")
          end
      end
    end
  end
end
