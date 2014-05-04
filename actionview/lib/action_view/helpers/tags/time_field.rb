module ActionView
  module Helpers
    module Tags # :nodoc:
      class TimeField < DatetimeField # :nodoc:
        private

          def format_date(value)
            value.do_or_do_not(:strftime, "%T.%L")
          end
      end
    end
  end
end
