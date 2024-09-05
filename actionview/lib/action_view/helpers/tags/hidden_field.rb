# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class HiddenField < TextField # :nodoc:
        def to_s
          @options[:autocomplete] = "off"
          super
        end
      end
    end
  end
end
