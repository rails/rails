# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class HiddenField < TextField # :nodoc:
        def render
          @options.reverse_merge!(autocomplete: "off")
          super
        end
      end
    end
  end
end
