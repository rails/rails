module ActionView
  module Helpers
    module Tags
      class FileField < TextField #:nodoc:
        def to_s
          @options.update(:size => nil)
          super
        end
      end
    end
  end
end
