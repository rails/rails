module ActionView
  module Helpers
    module Tags
      class TimeField < DatetimeField #:nodoc:
        private

          def format_date(value)
            value.try(:strftime, "%T.%L")
          end
      end
    end
  end
end
