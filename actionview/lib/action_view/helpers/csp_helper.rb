# frozen_string_literal: true

module ActionView
  # = Action View CSP Helper
  module Helpers #:nodoc:
    module CspHelper
      # Returns a meta tag "csp-nonce" with the per-session nonce value
      # for allowing inline <script> tags.
      #
      #   <head>
      #     <%= csp_meta_tag %>
      #   </head>
      #
      # This is used by the Rails UJS helper to create dynamically
      # loaded inline <script> elements.
      #
      def csp_meta_tag
        if content_security_policy?
          tag("meta", name: "csp-nonce", content: content_security_policy_nonce)
        end
      end
    end
  end
end
