# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class DatetimeLocalField < DatetimeField # :nodoc:
        class << self
          def field_type
            @field_type ||= "datetime-local"
          end
        end

        private
          def format_date(value)
            value.try(:strftime, "%Y-%m-%dT%T")
          end
      end
    end
  end
end
