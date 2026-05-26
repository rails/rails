# frozen_string_literal: true

require "test_helper"

class ActionMailbox::Ingresses::Mandrill::InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_key = ENV["MANDRILL_INGRESS_API_KEY"]
    ENV["MANDRILL_INGRESS_API_KEY"] = "1l9Qf7lutEf7h73VXfBwhw"
    ActionMailbox.ingress = :mandrill
    @events = JSON.generate([{ event: "inbound", msg: { raw_msg: file_fixture("../files/welcome.eml").read } }])
  end

  teardown do
    ENV["MANDRILL_INGRESS_API_KEY"] = @previous_key
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
    assert_equal file_fixture("../files/welcome.eml").read, inbound_email.raw_email.download
    assert_equal "0CB459E0-0336-41DA-BC88-E6E28C697DDB@37signals.com", inbound_email.message_id
  end

  test "rejecting a Mandrill events payload that is not a JSON array" do
    events = JSON.generate({ event: "inbound" })
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_mandrill_inbound_emails_url,
        headers: { "X-Mandrill-Signature" => signature_for(events) }, params: { mandrill_events: events }
    end

    assert_response :unprocessable_content
  end

  test "rejecting a Mandrill events payload that parses to null" do
    events = "null"
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_mandrill_inbound_emails_url,
        headers: { "X-Mandrill-Signature" => signature_for(events) }, params: { mandrill_events: events }
    end

    assert_response :unprocessable_content
  end

  test "rejecting a Mandrill events array that contains non-objects" do
    events = JSON.generate([{ event: "inbound" }, "not-a-hash"])
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_mandrill_inbound_emails_url,
        headers: { "X-Mandrill-Signature" => signature_for(events) }, params: { mandrill_events: events }
    end

    assert_response :unprocessable_content
  end

  test "rejecting a Mandrill events payload that parses to a scalar" do
    events = "42"
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_mandrill_inbound_emails_url,
        headers: { "X-Mandrill-Signature" => signature_for(events) }, params: { mandrill_events: events }
    end

    assert_response :unprocessable_content
  end

  test "rejecting a forged inbound email from Mandrill" do
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_mandrill_inbound_emails_url,
        headers: { "X-Mandrill-Signature" => "forged" }, params: { mandrill_events: @events }
    end

    assert_response :unauthorized
  end

  test "rejecting an inbound email from Mandrill without a signature" do
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_mandrill_inbound_emails_url, params: { mandrill_events: @events }
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
    def signature_for(events)
      message = rails_mandrill_inbound_emails_url + { "mandrill_events" => events }.sort.flatten.join
      Base64.strict_encode64 OpenSSL::HMAC.digest(OpenSSL::Digest::SHA1.new, ENV["MANDRILL_INGRESS_API_KEY"], message)
    end

    def switch_key_to(new_key)
      previous_key, ENV["MANDRILL_INGRESS_API_KEY"] = ENV["MANDRILL_INGRESS_API_KEY"], new_key
      yield
    ensure
      ENV["MANDRILL_INGRESS_API_KEY"] = previous_key
    end
end
