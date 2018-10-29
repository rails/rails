class ActionMailbox::BaseController < ActionController::Base
  skip_forgery_protection

  private
    def authenticate
      if username.present? && password.present?
        authenticate_or_request_with_http_basic("Action Mailbox") do |given_username, given_password|
          ActiveSupport::SecurityUtils.secure_compare(given_username, username) &
            ActiveSupport::SecurityUtils.secure_compare(given_password, password)
        end
      else
        raise ArgumentError, "Missing required ingress credentials"
      end
    end
end
