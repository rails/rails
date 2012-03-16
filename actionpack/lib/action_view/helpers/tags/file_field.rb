module ActionView
  module Helpers
    module Tags
      class FileField < TextField #:nodoc:
        def render
          @options.update(:size => nil)
          super
        end
      end
    end
  end
end
