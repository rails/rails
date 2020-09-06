# frozen_string_literal: true

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
      #   safe_join([raw("<p>foo</p>"), "<p>bar</p>"], "<br />")
      #   # => "<p>foo</p>&lt;br /&gt;&lt;p&gt;bar&lt;/p&gt;"
      #
      #   safe_join([raw("<p>foo</p>"), raw("<p>bar</p>")], raw("<br />"))
      #   # => "<p>foo</p><br /><p>bar</p>"
      #
      def safe_join(array, sep = $,)
        sep = ERB::Util.unwrapped_html_escape(sep)

        array.flatten.map! { |i| ERB::Util.unwrapped_html_escape(i) }.join(sep).html_safe
      end

      # Converts the array to a comma-separated sentence where the last element is
      # joined by the connector word. This is the html_safe-aware version of
      # ActiveSupport's {Array#to_sentence}[https://api.rubyonrails.org/classes/Array.html#method-i-to_sentence].
      #
      def to_sentence(array, options = {})
        options.assert_valid_keys(:words_connector, :two_words_connector, :last_word_connector, :locale)

        default_connectors = {
          words_connector: ', ',
          two_words_connector: ' and ',
          last_word_connector: ', and '
        }
        if defined?(I18n)
          i18n_connectors = I18n.translate(:'support.array', locale: options[:locale], default: {})
          default_connectors.merge!(i18n_connectors)
        end
        options = default_connectors.merge!(options)

        case array.length
        when 0
          ''.html_safe
        when 1
          ERB::Util.html_escape(array[0])
        when 2
          safe_join([array[0], array[1]], options[:two_words_connector])
        else
          safe_join([safe_join(array[0...-1], options[:words_connector]), options[:last_word_connector], array[-1]], nil)
        end
      end
    end
  end
end
