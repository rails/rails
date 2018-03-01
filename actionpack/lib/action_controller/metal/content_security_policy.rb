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
      def content_security_policy(**options, &block)
        before_action(options) do
          if block_given?
            policy = request.content_security_policy.clone
            yield policy
            request.content_security_policy = policy
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
  end
end
