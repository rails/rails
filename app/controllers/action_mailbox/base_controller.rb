class ActionMailbox::BaseController < ActionController::Base
  skip_forgery_protection

  private
    def authenticate
      authenticate_or_request_with_http_basic("Action Mailbox") do |given_username, given_password|
        ActiveSupport::SecurityUtils.secure_compare(given_username, username) &
          ActiveSupport::SecurityUtils.secure_compare(given_password, password)
      end
    end
end
