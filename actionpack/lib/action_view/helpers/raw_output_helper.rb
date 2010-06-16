module ActionView #:nodoc:
  # = Action View Raw Output Helper
  module Helpers #:nodoc:
    module RawOutputHelper
      # This method outputs without escaping a string. Since escaping tags is 
      # now default, this can be used when you don't want Rails to automatically
      # escape tags. This is not recommended if the data is coming from the user's
      # input.
      #
      # For example:
      #
      # <%=raw @user.name %>
      def raw(stringish)
        stringish.to_s.html_safe
      end
    end
  end
end