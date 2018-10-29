class ActionMailbox::BaseController < ActionController::Base
  skip_forgery_protection

  private
    def authenticate
      if username.present? && password.present?
        http_basic_authenticate_or_request_with username: username, password: password, realm: "Action Mailbox"
      else
        raise ArgumentError, "Missing required ingress credentials"
      end
    end

    # TODO: Extract to ActionController::HttpAuthentication
    def http_basic_authenticate_or_request_with(username:, password:, realm: nil)
      authenticate_or_request_with_http_basic(realm || "Application") do |given_username, given_password|
        ActiveSupport::SecurityUtils.secure_compare(given_username, username) &
          ActiveSupport::SecurityUtils.secure_compare(given_password, password)
      end
    end
end
