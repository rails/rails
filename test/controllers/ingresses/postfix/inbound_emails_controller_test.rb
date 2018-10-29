require "test_helper"

ActionMailbox::Ingresses::Postfix::InboundEmailsController.password = "tbsy84uSV1Kt3ZJZELY2TmShPRs91E3yL4tzf96297vBCkDWgL"

class ActionMailbox::Ingresses::Postfix::InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  test "receiving an inbound email from Postfix" do
    assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
      post rails_postfix_inbound_emails_url, headers: { "Authorization" => credentials, "Content-Type" => "message/rfc822" },
        params: file_fixture("../files/welcome.eml").read
    end

    assert_response :no_content

    inbound_email = ActionMailbox::InboundEmail.last
    assert_equal file_fixture("../files/welcome.eml").read, inbound_email.raw_email.download
    assert_equal "0CB459E0-0336-41DA-BC88-E6E28C697DDB@37signals.com", inbound_email.message_id
  end

  test "rejecting an unauthorized inbound email from Postfix" do
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_postfix_inbound_emails_url, headers: { "Content-Type" => "message/rfc822" },
        params: file_fixture("../files/welcome.eml").read
    end

    assert_response :unauthorized
  end

  test "rejecting an inbound email of an unsupported media type from Postfix" do
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_postfix_inbound_emails_url, headers: { "Authorization" => credentials, "Content-Type" => "text/plain" },
        params: file_fixture("../files/welcome.eml").read
    end

    assert_response :unsupported_media_type
  end

  test "raising when the configured password is nil" do
    switch_password_to nil do
      assert_raises ArgumentError do
        post rails_postfix_inbound_emails_url, headers: { "Authorization" => credentials, "Content-Type" => "message/rfc822" },
          params: file_fixture("../files/welcome.eml").read
      end
    end
  end

  test "raising when the configured password is blank" do
    switch_password_to "" do
      assert_raises ArgumentError do
        post rails_postfix_inbound_emails_url, headers: { "Authorization" => credentials, "Content-Type" => "message/rfc822" },
          params: file_fixture("../files/welcome.eml").read
      end
    end
  end

  private
    delegate :username, :password, :password=, to: ActionMailbox::Ingresses::Postfix::InboundEmailsController

    def credentials
      ActionController::HttpAuthentication::Basic.encode_credentials username, password
    end

    def switch_password_to(new_password)
      previous_password, self.password = password, new_password
      yield
    ensure
      self.password = previous_password
    end
end
