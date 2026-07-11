# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class NumberField < TextField # :nodoc:
        def render
          options = @options.stringify_keys

          if range = options.delete("in") || options.delete("within")
            options.update("min" => range.begin, "max" => max_for_range(range))
          end

          @options = options
          super
        end

        private
          # Range#max raises for an exclusive range that isn't a pure Integer range
          # (e.g. a Float range), so fall back to the end value in that case. The
          # HTML max attribute is an inclusive bound regardless.
          def max_for_range(range)
            return unless range.end
            range.max
          rescue TypeError
            range.end
          end
      end
    end
  end
end
