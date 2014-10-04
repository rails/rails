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
      #  raw @user.name
      #  # => 'Jimmy <alert>Tables</alert>'
      def raw(stringish)
        stringish.to_s.html_safe
      end

      # This method returns an HTML safe string similar to what <tt>Array#join</tt>
      # would return. The array is flattened, and all items, including
      # the supplied separator, are HTML escaped unless they are HTML
      # safe, and the returned string is marked as HTML safe.
      #
      #   safe_join(["<p>foo</p>".html_safe, "<p>bar</p>"], "<br />")
      #   # => "<p>foo</p>&lt;br /&gt;&lt;p&gt;bar&lt;/p&gt;"
      #
      #   safe_join(["<p>foo</p>".html_safe, "<p>bar</p>".html_safe], "<br />".html_safe)
      #   # => "<p>foo</p><br /><p>bar</p>"
      #
      def safe_join(array, sep=$,)
        sep = ERB::Util.unwrapped_html_escape(sep)

        array.flatten.map! { |i| ERB::Util.unwrapped_html_escape(i) }.join(sep).html_safe
      end
    end
  end
end
