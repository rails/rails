# frozen_string_literal: true

require "test_helper"

ENV["MANDRILL_INGRESS_API_KEY"] = "1l9Qf7lutEf7h73VXfBwhw"

class ActionMailbox::Ingresses::Mandrill::InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailbox.ingress = :mandrill
    raw_msg = file_fixture("../files/welcome.eml").read
    @events = JSON.generate([{ event: "inbound", msg: { raw_msg: Mail::Utilities.to_lf(raw_msg) } }])
  end

  test "verifying existence of Mandrill inbound route" do
    # Mandrill uses a HEAD request to verify if a URL exists before creating the ingress webhook
    head rails_mandrill_inbound_health_check_url
    assert_response :ok
  end

  test "receiving an inbound email from Mandrill" do
    assert_difference -> { ActionMailbox::InboundEmail.count }, +1 do
      post rails_mandrill_inbound_emails_url,
        headers: { "X-Mandrill-Signature" => "1bNbyqkMFL4VYIT5+RQCrPs/mRY=" }, params: { mandrill_events: @events }
    end

    assert_response :ok

    inbound_email = ActionMailbox::InboundEmail.last
    expected_message = Mail::Utilities.to_lf(file_fixture("../files/welcome.eml").read)
    assert_equal expected_message, inbound_email.raw_email.download
    assert_equal "0CB459E0-0336-41DA-BC88-E6E28C697DDB@37signals.com", inbound_email.message_id
  end

  test "rejecting a forged inbound email from Mandrill" do
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_mandrill_inbound_emails_url,
        headers: { "X-Mandrill-Signature" => "forged" }, params: { mandrill_events: @events }
    end

    assert_response :unauthorized
  end

  test "raising when Mandrill API key is nil" do
    switch_key_to nil do
      assert_raises ArgumentError do
        post rails_mandrill_inbound_emails_url,
          headers: { "X-Mandrill-Signature" => "gldscd2tAb/G+DmpiLcwukkLrC4=" }, params: { mandrill_events: @events }
      end
    end
  end

  test "raising when Mandrill API key is blank" do
    switch_key_to "" do
      assert_raises ArgumentError do
        post rails_mandrill_inbound_emails_url,
          headers: { "X-Mandrill-Signature" => "gldscd2tAb/G+DmpiLcwukkLrC4=" }, params: { mandrill_events: @events }
      end
    end
  end

  private
    def switch_key_to(new_key)
      previous_key, ENV["MANDRILL_INGRESS_API_KEY"] = ENV["MANDRILL_INGRESS_API_KEY"], new_key
      yield
    ensure
      ENV["MANDRILL_INGRESS_API_KEY"] = previous_key
    end
end
