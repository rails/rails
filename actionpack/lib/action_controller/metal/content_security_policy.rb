# frozen_string_literal: true

# :markup: markdown

module ActionController # :nodoc:
  module ContentSecurityPolicy
    extend ActiveSupport::Concern

    include AbstractController::Helpers
    include AbstractController::Callbacks

    included do
      helper_method :content_security_policy?
      helper_method :content_security_policy_nonce
    end

    module ClassMethods
      # Overrides parts of the globally configured `Content-Security-Policy` header:
      #
      #     class PostsController < ApplicationController
      #       content_security_policy do |policy|
      #         policy.base_uri "https://www.example.com"
      #       end
      #     end
      #
      # Options can be passed similar to `before_action`. For example, pass `only:
      # :index` to override the header on the index action only:
      #
      #     class PostsController < ApplicationController
      #       content_security_policy(only: :index) do |policy|
      #         policy.default_src :self, :https
      #       end
      #     end
      #
      # Pass `false` to remove the `Content-Security-Policy` header:
      #
      #     class PostsController < ApplicationController
      #       content_security_policy false, only: :index
      #     end
      def content_security_policy(enabled = true, **options, &block)
        before_action(options) do
          if block_given?
            policy = current_content_security_policy
            instance_exec(policy, &block)
            request.content_security_policy = policy
          end

          unless enabled
            request.content_security_policy = nil
          end
        end
      end

      # Overrides parts of the globally configured
      # `Content-Security-Policy-Report-Only` header. The report-only policy is
      # sent alongside the `Content-Security-Policy` header, so a stricter policy
      # can be tested without enforcing it:
      #
      #     class PostsController < ApplicationController
      #       content_security_policy_report_only do |policy|
      #         policy.script_src :self
      #       end
      #     end
      #
      # Without a block, the `Content-Security-Policy` is sent as
      # `Content-Security-Policy-Report-Only` instead of being enforced:
      #
      #     class PostsController < ApplicationController
      #       content_security_policy_report_only only: :index
      #     end
      #
      # Pass `false` to remove the `Content-Security-Policy-Report-Only` header:
      #
      #     class PostsController < ApplicationController
      #       content_security_policy_report_only false, only: :index
      #     end
      def content_security_policy_report_only(enabled = true, **options, &block)
        before_action(options) do
          if !enabled
            request.content_security_policy_report_only = false
          elsif block_given?
            policy = current_content_security_policy_report_only
            instance_exec(policy, &block)
            request.content_security_policy_report_only = policy
          else
            request.content_security_policy_report_only = true
          end
        end
      end
    end

    private
      def content_security_policy?
        request.content_security_policy || report_only_policy.present?
      end

      def content_security_policy_nonce
        request.content_security_policy_nonce
      end

      def current_content_security_policy
        request.content_security_policy&.clone || ActionDispatch::ContentSecurityPolicy.new
      end

      def current_content_security_policy_report_only
        report_only_policy&.clone || ActionDispatch::ContentSecurityPolicy.new
      end

      # `request.content_security_policy_report_only` is either a boolean or a
      # separate policy.
      def report_only_policy
        policy = request.content_security_policy_report_only
        policy if policy.is_a?(ActionDispatch::ContentSecurityPolicy)
      end
  end
end
