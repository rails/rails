module ActionView
  # = Action View CSRF Helper
  module Helpers
    module CsrfHelper
      # Returns a meta tag with the cross-site request forgery protection token
      # for forms to use. Place this in your head.
      def csrf_meta_tag
        if protect_against_forgery?
          %(<meta name="csrf-param" content="#{h(request_forgery_protection_token)}"/>\n<meta name="csrf-token" content="#{h(form_authenticity_token)}"/>).html_safe
        end
      end
    end
  end
end
