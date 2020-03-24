# frozen_string_literal: true

require "test_helper"

ENV["MAILGUN_INGRESS_SIGNING_KEY"] = "tbsy84uSV1Kt3ZJZELY2TmShPRs91E3yL4tzf96297vBCkDWgL"

class ActionMailbox::Ingresses::Mailgun::InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  setup { ActionMailbox.ingress = :mailgun }

  test "receiving an inbound email from Mailgun" do
    assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
      travel_to "2018-10-09 15:15:00 EDT"
      post rails_mailgun_inbound_emails_url, params: {
        timestamp: 1539112500,
        token: "7VwW7k6Ak7zcTwoSoNm7aTtbk1g67MKAnsYLfUB7PdszbgR5Xi",
        signature: "ef24c5225322217bb065b80bb54eb4f9206d764e3e16abab07f0a64d1cf477cc",
        "body-mime" => file_fixture("../files/welcome.eml").read
      }
    end

    assert_response :no_content

    inbound_email = ActionMailbox::InboundEmail.last
    assert_equal file_fixture("../files/welcome.eml").read, inbound_email.raw_email.download
    assert_equal "0CB459E0-0336-41DA-BC88-E6E28C697DDB@37signals.com", inbound_email.message_id
  end

  test "add X-Original-To to email from Mailgun" do
    assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
      travel_to "2018-10-09 15:15:00 EDT"
      post rails_mailgun_inbound_emails_url, params: {
        timestamp: 1539112500,
        token: "7VwW7k6Ak7zcTwoSoNm7aTtbk1g67MKAnsYLfUB7PdszbgR5Xi",
        signature: "ef24c5225322217bb065b80bb54eb4f9206d764e3e16abab07f0a64d1cf477cc",
        "body-mime" => file_fixture("../files/welcome.eml").read,
        recipient: "replies@example.com"
      }
    end

    assert_response :no_content

    inbound_email = ActionMailbox::InboundEmail.last
    mail = Mail.from_source(inbound_email.raw_email.download)
    assert_equal "replies@example.com", mail.header["X-Original-To"].decoded
  end

  test "rejecting a delayed inbound email from Mailgun" do
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      travel_to "2018-10-09 15:26:00 EDT"
      post rails_mailgun_inbound_emails_url, params: {
        timestamp: 1539112500,
        token: "7VwW7k6Ak7zcTwoSoNm7aTtbk1g67MKAnsYLfUB7PdszbgR5Xi",
        signature: "ef24c5225322217bb065b80bb54eb4f9206d764e3e16abab07f0a64d1cf477cc",
        "body-mime" => file_fixture("../files/welcome.eml").read
      }
    end

    assert_response :unauthorized
  end

  test "rejecting a forged inbound email from Mailgun" do
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      travel_to "2018-10-09 15:15:00 EDT"
      post rails_mailgun_inbound_emails_url, params: {
        timestamp: 1539112500,
        token: "Zx8mJBiGmiiyyfWnho3zKyjCg2pxLARoCuBM7X9AKCioShGiMX",
        signature: "ef24c5225322217bb065b80bb54eb4f9206d764e3e16abab07f0a64d1cf477cc",
        "body-mime" => file_fixture("../files/welcome.eml").read
      }
    end

    assert_response :unauthorized
  end

  test "raising when the configured Mailgun Signing key is nil" do
    switch_key_to nil do
      assert_raises ArgumentError do
        travel_to "2018-10-09 15:15:00 EDT"
        post rails_mailgun_inbound_emails_url, params: {
          timestamp: 1539112500,
          token: "7VwW7k6Ak7zcTwoSoNm7aTtbk1g67MKAnsYLfUB7PdszbgR5Xi",
          signature: "ef24c5225322217bb065b80bb54eb4f9206d764e3e16abab07f0a64d1cf477cc",
          "body-mime" => file_fixture("../files/welcome.eml").read
        }
      end
    end
  end

  test "raising when the configured Mailgun Signing key is blank" do
    switch_key_to "" do
      assert_raises ArgumentError do
        travel_to "2018-10-09 15:15:00 EDT"
        post rails_mailgun_inbound_emails_url, params: {
          timestamp: 1539112500,
          token: "7VwW7k6Ak7zcTwoSoNm7aTtbk1g67MKAnsYLfUB7PdszbgR5Xi",
          signature: "ef24c5225322217bb065b80bb54eb4f9206d764e3e16abab07f0a64d1cf477cc",
          "body-mime" => file_fixture("../files/welcome.eml").read
        }
      end
    end
  end

  private
    def switch_key_to(new_key)
      previous_key, ENV["MAILGUN_INGRESS_SIGNING_KEY"] = ENV["MAILGUN_INGRESS_SIGNING_KEY"], new_key
      yield
    ensure
      ENV["MAILGUN_INGRESS_SIGNING_KEY"] = previous_key
    end
end
