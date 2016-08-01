module ActionView
  module Helpers
    module Tags # :nodoc:
      class PasswordField < TextField # :nodoc:
        def render
          @options = {:value => nil, :autocomplete => 'off' }.merge!(@options)
          super
        end
      end
    end
  end
end
