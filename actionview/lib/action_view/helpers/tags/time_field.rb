module ActionView
  module Helpers
    module Tags # :nodoc:
      class TimeField < DatetimeField # :nodoc:
        private

          def format_date(value)
            value.try(:strftime, "%T.%L")
          end
      end
    end
  end
end
