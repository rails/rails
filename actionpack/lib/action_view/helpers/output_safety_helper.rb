require 'active_support/core_ext/string/output_safety'

module ActionView #:nodoc:
  # = Action View Raw Output Helper
  module Helpers #:nodoc:
    module OutputSafetyHelper
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

      # This method returns a html safe string using <tt>Array#join</tt> if all
      # the items in the array, including the supplied separator, are html safe.
      # Otherwise the result of <tt>Array#join</tt> is returned without marking
      # it as html safe.
      #
      #   safe_join(["Mr", "Bojangles"]).html_safe?
      #   # => false
      #
      #   safe_join(["Mr".html_safe, "Bojangles".html_safe]).html_safe?
      #   # => true
      #
      def safe_join(array, sep=$,)
        sep ||= "".html_safe
        str = array.join(sep)

        is_html_safe = array.all? { |item| item.html_safe? }

        (sep.html_safe? && is_html_safe) ? str.html_safe : str
      end
    end
  end
end