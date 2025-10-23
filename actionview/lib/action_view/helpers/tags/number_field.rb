# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class NumberField < TextField # :nodoc:
        def attributes
          options = @options.stringify_keys

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
