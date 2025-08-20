# frozen_string_literal: true

require "action_controller"

class Rails::ApplicationController < ActionController::Base # :nodoc:
  prepend_view_path File.expand_path("templates", __dir__)
  layout "application"

  before_action :disable_content_security_policy_nonce!

  content_security_policy do |policy|
    policy.script_src :self, :unsafe_inline
    policy.style_src :self, :unsafe_inline
  end

  private
    def require_local!
      unless local_request?
        render html: "<p>For security purposes, this information is only available to local requests.</p>".html_safe, status: :forbidden
      end
    end

    def local_request?
      Rails.application.config.consider_all_requests_local || request.local?
    end

    def disable_content_security_policy_nonce!
      request.content_security_policy_nonce_generator = nil
    end
end
