# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class TimeField < DatetimeField # :nodoc:
        def initialize(object_name, method_name, template_object, options = {})
          @include_seconds = options.delete(:include_seconds) { true }
          super
        end

        private
          def format_datetime(value)
            if @include_seconds
              value&.strftime("%T.%L")
            else
              value&.strftime("%H:%M")
            end
          end
      end
    end
  end
end
