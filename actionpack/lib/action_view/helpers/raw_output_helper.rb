module ActionView #:nodoc:
  module Helpers #:nodoc:
    module RawOutputHelper
      def raw(stringish)
        stringish.to_s.html_safe
      end
    end
  end
end
