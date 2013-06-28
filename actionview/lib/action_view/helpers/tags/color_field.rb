module ActionView
  module Helpers
    module Tags # :nodoc:
      class ColorField < TextField # :nodoc:
        def render
          options = @options.stringify_keys
          options["value"] = options.fetch("value") { validate_color_string(value(object)) }
          @options = options
          super
        end

        private

          def validate_color_string(string)
            regex = /#[0-9a-fA-F]{6}/
            if regex.match(string)
              string.downcase
            else
              "#000000"
            end
          end
      end
    end
  end
end
