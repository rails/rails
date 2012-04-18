module ActionView
  module Helpers
    module Tags
      class NumberField < TextField #:nodoc:
        def render
          options = @options.stringify_keys
          options['size'] ||= nil

          if range = options.delete("in") || options.delete("within")
            options.update("min" => range.min, "max" => range.max)
          end

          @options = options
          super
        end
      end
    end
  end
end
