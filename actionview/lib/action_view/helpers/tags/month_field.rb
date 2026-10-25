# frozen_string_literal: true

# :markup: markdown
module ActionView
  module Helpers
    module Tags # :nodoc:
      class MonthField < DatetimeField # :nodoc:
        private
          def format_datetime(value)
            value&.strftime("%Y-%m")
          end
      end
    end
  end
end
