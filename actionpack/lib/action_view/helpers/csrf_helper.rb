module ActionView
  module Helpers
    module CsrfHelper
      # Returns a meta tag with the request forgery protection token for forms to use. Put this in your head.
      def csrf_meta_tag
        if protect_against_forgery?
          %(<meta name="csrf-param" content="#{Rack::Utils.escape_html(request_forgery_protection_token)}"/>\n<meta name="csrf-token" content="#{Rack::Utils.escape_html(form_authenticity_token)}"/>).html_safe
        end
      end
    end
  end
end
