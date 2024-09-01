# frozen_string_literal: true

require "test_helper"

class ActionMailbox::Ingresses::Postmark::InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  setup { ActionMailbox.ingress = :postmark }

  test "receiving an inbound email from Postmark" do
    assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
      post rails_postmark_inbound_emails_url,
        headers: { authorization: credentials }, params: { RawEmail: file_fixture("../files/welcome.eml").read }
    end

    assert_response :no_content

    inbound_email = ActionMailbox::InboundEmail.last
    assert_equal file_fixture("../files/welcome.eml").read, inbound_email.raw_email.download
    assert_equal "0CB459E0-0336-41DA-BC88-E6E28C697DDB@37signals.com", inbound_email.message_id
  end

  test "receiving an inbound email from Postmark with non UTF-8 characters" do
    assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
      post rails_postmark_inbound_emails_url,
           headers: { authorization: credentials }, params: { RawEmail: file_fixture("../files/invalid_utf.eml").read }
    end

    assert_response :no_content

    inbound_email = ActionMailbox::InboundEmail.last
    assert_equal file_fixture("../files/invalid_utf.eml").binread, inbound_email.raw_email.download
    assert_equal "05988AA6EC0D44318855A5E39E3B6F9E@jansterba.com", inbound_email.message_id
  end

  test "add X-Original-To to email from Postmark" do
    assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
      post rails_postmark_inbound_emails_url,
        headers: { authorization: credentials }, params: {
          RawEmail: file_fixture("../files/welcome.eml").read,
          OriginalRecipient: "thisguy@domain.abcd",
        }
    end

    assert_response :no_content

    inbound_email = ActionMailbox::InboundEmail.last
    mail = Mail.from_source(inbound_email.raw_email.download)
    assert_equal "thisguy@domain.abcd", mail.header["X-Original-To"].decoded
  end

  test "rejecting when RawEmail param is missing" do
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_postmark_inbound_emails_url,
        headers: { authorization: credentials }, params: { From: "someone@example.com" }
    end

    assert_response :unprocessable_entity
  end

  test "rejecting an unauthorized inbound email from Postmark" do
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_postmark_inbound_emails_url, params: { RawEmail: file_fixture("../files/welcome.eml").read }
    end

    assert_response :unauthorized
  end

  test "raising when the configured password is nil" do
    switch_password_to nil do
      assert_raises ArgumentError do
        post rails_postmark_inbound_emails_url,
          headers: { authorization: credentials }, params: { RawEmail: file_fixture("../files/welcome.eml").read }
      end
    end
  end

  test "raising when the configured password is blank" do
    switch_password_to "" do
      assert_raises ArgumentError do
        post rails_postmark_inbound_emails_url,
          headers: { authorization: credentials }, params: { RawEmail: file_fixture("../files/welcome.eml").read }
      end
    end
  end
end
