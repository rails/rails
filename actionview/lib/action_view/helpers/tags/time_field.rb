# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class TimeField < DatetimeField # :nodoc:
        private
          def format_date(value)
            value&.strftime('%T.%L')
          end
      end
    end
  end
end
