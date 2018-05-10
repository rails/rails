# frozen_string_literal: true

module ActionController #:nodoc:
  module ContentSecurityPolicy
    # TODO: Documentation
    extend ActiveSupport::Concern

    include AbstractController::Helpers
    include AbstractController::Callbacks

    included do
      helper_method :content_security_policy?
      helper_method :content_security_policy_nonce
    end

    module ClassMethods
      def content_security_policy(enabled = true, **options)
        before_action(options) do
          if block_given?
            policy = current_content_security_policy
            yield policy
            request.content_security_policy = policy
          end

          unless enabled
            request.content_security_policy = nil
          end
        end
      end

      def content_security_policy_report_only(report_only = true, **options)
        before_action(options) do
          request.content_security_policy_report_only = report_only
        end
      end
    end

    private

      def content_security_policy?
        request.content_security_policy
      end

      def content_security_policy_nonce
        request.content_security_policy_nonce
      end

      def current_content_security_policy
        request.content_security_policy.try(:clone) || ActionDispatch::ContentSecurityPolicy.new
      end
  end
end
