module ActionView
  module Helpers
    module Tags
      class HiddenField < TextField #:nodoc:
        def render
          @options.update(:size => nil)
          super
        end
      end
    end
  end
end
