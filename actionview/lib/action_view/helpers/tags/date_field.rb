module ActionView
  module Helpers
    module Tags # :nodoc:
      class DateField < DatetimeField # :nodoc:
        private

          def format_date(value)
            value.try(:strftime, "%Y-%m-%d")
          end
      end
    end
  end
end
