# frozen_string_literal: true

module ActionView
  module Helpers
    module Tags # :nodoc:
      class PasswordField < TextField # :nodoc:
        def attributes
          @options = { value: nil }.merge!(@options)
          super
        end
      end
    end
  end
end
