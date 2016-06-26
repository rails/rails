module ActionView
  module Helpers
    module Tags # :nodoc:
      class DatetimeField < TextField # :nodoc:
        def render
          options = @options.stringify_keys
          options["value"] ||= format_date(value(object))
          options["min"] = format_date(datetime_value(options["min"]))
          options["max"] = format_date(datetime_value(options["max"]))
          @options = options
          super
        end

        private

          def format_date(value)
            raise NotImplementedError
          end

          def datetime_value(value)
            if value.is_a? String
              DateTime.parse(value) rescue nil
            else
              value
            end
          end
      end
    end
  end
end
