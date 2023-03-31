# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class DatetimeField < TextField # :nodoc:
        def render
          options = @options.stringify_keys
          options["value"] = normalize_datetime(options["value"] || value)
          options["min"] = normalize_datetime(options["min"])
          options["max"] = normalize_datetime(options["max"])
          @options = options
          super
        end

        private
          def format_datetime(value)
            raise NotImplementedError
          end

          def normalize_datetime(value)
            format_datetime(parse_datetime(value))
          end

          def parse_datetime(value)
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
