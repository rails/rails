# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class ColorField < TextField # :nodoc:
        private
          def fallback_value
            validate_color_string(value)
          end

          def validate_color_string(string)
            regex = /\A#[0-9a-fA-F]{6}\z/
            if regex.match?(string)
              string.downcase
            else
              "#000000"
            end
          end
      end
    end
  end
end
