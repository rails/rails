# frozen_string_literal: true

require "test_helper"
require "base64"
require "securerandom"

ENV["RESEND_WEBHOOK_SECRET"] = "whsec_#{Base64.strict_encode64("topsecret")}"

class ActionMailbox::Ingresses::Resend::InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailbox.ingress = :resend
  end

  test "receiving an inbound email from Resend" do
    payload = resend_payload(raw_email: file_fixture("../files/welcome.eml").binread, to: "replies@example.com")

    assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
      post rails_resend_inbound_emails_url, params: payload, headers: signature_headers(payload)
    end

    assert_response :no_content

    inbound_email = ActionMailbox::InboundEmail.last
    mail = Mail.from_source(inbound_email.raw_email.download)
    assert_equal "replies@example.com", mail.header["X-Original-To"].decoded
  end

  test "rejecting a forged inbound email from Resend" do
    payload = resend_payload(raw_email: file_fixture("../files/welcome.eml").binread)

    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_resend_inbound_emails_url, params: payload, headers: signature_headers(payload, secret: "whsec_#{Base64.strict_encode64("badsecret")}")
    end

    assert_response :unauthorized
  end

  test "rejecting a stale inbound email from Resend" do
    payload = resend_payload(raw_email: file_fixture("../files/welcome.eml").binread)

    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      travel_to 10.minutes.from_now do
        post rails_resend_inbound_emails_url, params: payload, headers: signature_headers(payload, timestamp: 15.minutes.ago)
      end
    end

    assert_response :unauthorized
  end

  test "rejecting a malformed payload" do
    payload = { type: "email.received", data: { email: {} } }.to_json

    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_resend_inbound_emails_url, params: payload, headers: signature_headers(payload)
    end

    assert_response ActionDispatch::Constants::UNPROCESSABLE_CONTENT
  end

  private
    def resend_payload(raw_email:, to: nil)
      data = { type: "email.received", data: { email: { raw: Base64.strict_encode64(raw_email) } } }
      data[:data][:email][:to] = Array(to) if to
      JSON.generate(data)
    end

    def signature_headers(payload, secret: ENV.fetch("RESEND_WEBHOOK_SECRET"), timestamp: Time.current)
      id = "evt_#{SecureRandom.hex(8)}"
      ts = timestamp.to_i
      key = Base64.decode64(secret.sub(/\Awhsec_/, ""))
      signed_payload = [id, ts, payload].join(".")
      signature = Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", key, signed_payload))

      {
        "Svix-Id" => id,
        "Svix-Timestamp" => ts.to_s,
        "Svix-Signature" => "v1,#{signature}",
        "CONTENT_TYPE" => "application/json"
      }
    end
end
