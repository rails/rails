require_relative '../test_helper'

class ActionMailroom::InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  test "receiving a valid RFC 822 message" do
    assert_difference -> { ActionMailroom::InboundEmail.count }, +1 do
      post_inbound_email "welcome.eml"
    end

    assert_response :created

    inbound_email = ActionMailroom::InboundEmail.last
    assert_equal file_fixture('../files/welcome.eml').read, inbound_email.raw_email.download
  end

  test "rejecting a message of an unsupported type" do
    assert_no_difference -> { ActionMailroom::InboundEmail.count } do
      post rails_inbound_emails_url, params: { message: fixture_file_upload('files/text.txt', 'text/plain') }
    end

    assert_response :unsupported_media_type
  end

  private
    def post_inbound_email(fixture_name)
      post rails_inbound_emails_url, params: { message: fixture_file_upload("files/#{fixture_name}", 'message/rfc822') }
    end
end
