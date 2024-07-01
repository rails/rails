# frozen_string_literal: true

module ActionView
  module Helpers # :nodoc:
    # = Action View CSP \Helpers
    module CspHelper
      mattr_accessor :rename_csp_helper_nonce_attribute
      self.rename_csp_helper_nonce_attribute = nil

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
          nonce_attribute_name = rename_csp_helper_nonce_attribute ? :nonce : :content
          options[nonce_attribute_name] = content_security_policy_nonce
          tag("meta", options)
        end
      end
    end
  end
end
