# frozen_string_literal: true

require_relative "../test_helper"

require "action_mailbox/postfix_relayer"

module ActionMailbox
  class PostfixRelayerTest < ActiveSupport::TestCase
    URL = "https://example.com/rails/action_mailbox/postfix/inbound_emails"
    INGRESS_PASSWORD = "secret"

    setup do
      @relayer = ActionMailbox::PostfixRelayer.new(url: URL, password: INGRESS_PASSWORD)
    end

    test "successfully relaying an email" do
      stub_request(:post, URL).to_return status: 204

      result = @relayer.relay(file_fixture("welcome.eml").read)
      assert_equal "2.0.0 Successfully relayed message to Postfix ingress", result.output
      assert result.success?
      assert_not result.failure?

      assert_requested :post, URL, body: file_fixture("welcome.eml").read,
        basic_auth: [ "actionmailbox", INGRESS_PASSWORD ],
        headers: { "Content-Type" => "message/rfc822", "User-Agent" => /\AAction Mailbox Postfix relayer v\d+\./ }
    end

    test "unsuccessfully relaying with invalid credentials" do
      stub_request(:post, URL).to_return status: 401

      result = @relayer.relay(file_fixture("welcome.eml").read)
      assert_equal "4.7.0 Invalid credentials for Postfix ingress", result.output
      assert_not result.success?
      assert result.failure?
    end

    test "unsuccessfully relaying due to an unspecified server error" do
      stub_request(:post, URL).to_return status: 500

      result = @relayer.relay(file_fixture("welcome.eml").read)
      assert_equal "4.0.0 HTTP 500", result.output
      assert_not result.success?
      assert result.failure?
    end

    test "unsuccessfully relaying due to a gateway timeout" do
      stub_request(:post, URL).to_return status: 504

      result = @relayer.relay(file_fixture("welcome.eml").read)
      assert_equal "4.0.0 HTTP 504", result.output
      assert_not result.success?
      assert result.failure?
    end

    test "unsuccessfully relaying due to ECONNRESET" do
      stub_request(:post, URL).to_raise Errno::ECONNRESET.new

      result = @relayer.relay(file_fixture("welcome.eml").read)
      assert_equal "4.4.2 Network error relaying to Postfix ingress: Connection reset by peer", result.output
      assert_not result.success?
      assert result.failure?
    end

    test "unsuccessfully relaying due to connection failure" do
      stub_request(:post, URL).to_raise SocketError.new("Failed to open TCP connection to example.com:443")

      result = @relayer.relay(file_fixture("welcome.eml").read)
      assert_equal "4.4.2 Network error relaying to Postfix ingress: Failed to open TCP connection to example.com:443", result.output
      assert_not result.success?
      assert result.failure?
    end

    test "unsuccessfully relaying due to client-side timeout" do
      stub_request(:post, URL).to_timeout

      result = @relayer.relay(file_fixture("welcome.eml").read)
      assert_equal "4.4.2 Timed out relaying to Postfix ingress", result.output
      assert_not result.success?
      assert result.failure?
    end

    test "unsuccessfully relaying due to an unhandled exception" do
      stub_request(:post, URL).to_raise StandardError.new("Something went wrong")

      result = @relayer.relay(file_fixture("welcome.eml").read)
      assert_equal "4.0.0 Error relaying to Postfix ingress: Something went wrong", result.output
      assert_not result.success?
      assert result.failure?
    end
  end
end
