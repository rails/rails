# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class DatetimeLocalField < DatetimeField # :nodoc:
        def initialize(object_name, method_name, template_object, options = {})
          @include_seconds = options.delete(:include_seconds) { true }
          super
        end

        @field_type = "datetime-local"

        private
          def format_datetime(value)
            if @include_seconds
              value&.strftime("%Y-%m-%dT%T")
            else
              value&.strftime("%Y-%m-%dT%H:%M")
            end
          end
      end
    end
  end
end
