# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class HiddenField < TextField # :nodoc:
        def render
          autocomplete = @options.fetch(:autocomplete, "off")
          @options[:autocomplete] = autocomplete
          super
        end
      end
    end
  end
end
