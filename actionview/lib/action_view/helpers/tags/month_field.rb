module ActionView
  module Helpers
    module Tags # :nodoc:
      class MonthField < DatetimeField # :nodoc:
        private

          def format_date(value)
            value.try(:strftime, "%Y-%m")
          end
      end
    end
  end
end
