module ActionView
  module Helpers
    module Tags # :nodoc:
      class PasswordField < TextField # :nodoc:
        def render
          @options = @options.reverse_merge(value: nil)

          super
        end
      end
    end
  end
end
