require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/output_safety'
require 'action_view/helpers/tag_helper'
require 'action_dispatch'

module ActionView
  # = Action View Charset Helper
  module Helpers
    module CharsetHelper
      # Returns meta tags "charset".
      #
      #   <head>
      #     <%= charset_meta_tag %>
      #     <title>...</title>
      #   </head>
      #
      # This method will return the meta tag with charset value looking for in this order:
      #   charset argument
      #   ActionDispatch::Response#charset
      #   ActionDispatch::Response.default_charset
      #
      def charset_meta_tag(charset = nil)
        tag('meta', :charset => (charset || response.charset || ActionDispatch::Response.default_charset)).html_safe
      end

    end
  end
end
