module ActionView
  module Helpers
    module Tags # :nodoc:
      class PasswordField < TextField # :nodoc:
        def render
          @options = {:value => nil}.merge!(@options)
          super
        end
      end
    end
  end
end
