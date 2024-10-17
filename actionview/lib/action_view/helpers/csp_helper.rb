# frozen_string_literal: true

module ActionView
  module Helpers # :nodoc:
    # = Action View CSP \Helpers
    module CspHelper
      mattr_accessor :csp_meta_tag_nonce_attribute, default: :content

      # Returns a meta tag "csp-nonce" with the per-session nonce value
      # for allowing inline <script> tags.
      #
      #   <head>
      #     <%= csp_meta_tag %>
      #   </head>
      #
      # This is used by the \Rails UJS helper to create dynamically
      # loaded inline <script> elements.
      #
      def csp_meta_tag(**options)
        if content_security_policy?
          options[:name] = "csp-nonce"
          options[csp_meta_tag_nonce_attribute] = content_security_policy_nonce
          tag("meta", options)
        end
      end
    end
  end
end
