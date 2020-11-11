# frozen_string_literal: true

require "action_view/helpers/tags/validator"

module ActionView
  module Helpers
    module Tags # :nodoc:
      class HiddenField < TextField # :nodoc:
        def initialize(*)
          super

          @validator = NullValidator.new
        end
      end
    end
  end
end
