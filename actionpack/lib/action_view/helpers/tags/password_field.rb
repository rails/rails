module ActionView
  module Helpers
    module Tags
      class PasswordField < TextField #:nodoc:
        def to_s
          @options = {:value => nil}.merge!(@options)
          super
        end
      end
    end
  end
end
