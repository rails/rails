require 'active_support/core_ext/string/strip'

module ActionView
  # = Action View CSRF Helper
  module Helpers
    module CsrfHelper
      # Returns meta tags "csrf-param" and "csrf-token" with the name of the cross-site
      # request forgery protection parameter and token, respectively.
      #
      #   <head>
      #     <%= csrf_meta_tags %>
      #   </head>
      #
      # These are used to generate the dynamic forms that implement non-remote links with
      # <tt>:method</tt>.
      #
      # Note that regular forms generate hidden fields, and that Ajax calls are whitelisted,
      # so they do not use these tags.
      def csrf_meta_tags
        <<-METAS.strip_heredoc.chomp.html_safe if protect_against_forgery?
          <meta name="csrf-param" content="#{Rack::Utils.escape_html(request_forgery_protection_token)}"/>
          <meta name="csrf-token" content="#{Rack::Utils.escape_html(form_authenticity_token)}"/>
        METAS
      end

      # For backwards compatibility.
      alias csrf_meta_tag csrf_meta_tags
    end
  end
end
