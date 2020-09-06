# frozen_string_literal: true

require_relative '../test_helper'

require 'action_mailbox/relayer'

module ActionMailbox
  class RelayerTest < ActiveSupport::TestCase
    URL = 'https://example.com/rails/action_mailbox/relay/inbound_emails'
    INGRESS_PASSWORD = 'secret'

    setup do
      @relayer = ActionMailbox::Relayer.new(url: URL, password: INGRESS_PASSWORD)
    end

    test 'successfully relaying an email' do
      stub_request(:post, URL).to_return status: 204

      result = @relayer.relay(file_fixture('welcome.eml').read)
      assert_equal '2.0.0', result.status_code
      assert_equal 'Successfully relayed message to ingress', result.message
      assert result.success?
      assert_not result.failure?

      assert_requested :post, URL, body: file_fixture('welcome.eml').read,
        basic_auth: [ 'actionmailbox', INGRESS_PASSWORD ],
        headers: { 'Content-Type' => 'message/rfc822', 'User-Agent' => /\AAction Mailbox relayer v\d+\./ }
    end

    test 'unsuccessfully relaying with invalid credentials' do
      stub_request(:post, URL).to_return status: 401

      result = @relayer.relay(file_fixture('welcome.eml').read)
      assert_equal '4.7.0', result.status_code
      assert_equal 'Invalid credentials for ingress', result.message
      assert_not result.success?
      assert result.failure?
    end

    test 'unsuccessfully relaying due to an unspecified server error' do
      stub_request(:post, URL).to_return status: 500

      result = @relayer.relay(file_fixture('welcome.eml').read)
      assert_equal '4.0.0', result.status_code
      assert_equal 'HTTP 500', result.message
      assert_not result.success?
      assert result.failure?
    end

    test 'unsuccessfully relaying due to a gateway timeout' do
      stub_request(:post, URL).to_return status: 504

      result = @relayer.relay(file_fixture('welcome.eml').read)
      assert_equal '4.0.0', result.status_code
      assert_equal 'HTTP 504', result.message
      assert_not result.success?
      assert result.failure?
    end

    test 'unsuccessfully relaying due to ECONNRESET' do
      stub_request(:post, URL).to_raise Errno::ECONNRESET.new

      result = @relayer.relay(file_fixture('welcome.eml').read)
      assert_equal '4.4.2', result.status_code
      assert_equal 'Network error relaying to ingress: Connection reset by peer', result.message
      assert_not result.success?
      assert result.failure?
    end

    test 'unsuccessfully relaying due to connection failure' do
      stub_request(:post, URL).to_raise SocketError.new('Failed to open TCP connection to example.com:443')

      result = @relayer.relay(file_fixture('welcome.eml').read)
      assert_equal '4.4.2', result.status_code
      assert_equal 'Network error relaying to ingress: Failed to open TCP connection to example.com:443', result.message
      assert_not result.success?
      assert result.failure?
    end

    test 'unsuccessfully relaying due to client-side timeout' do
      stub_request(:post, URL).to_timeout

      result = @relayer.relay(file_fixture('welcome.eml').read)
      assert_equal '4.4.2', result.status_code
      assert_equal 'Timed out relaying to ingress', result.message
      assert_not result.success?
      assert result.failure?
    end

    test 'unsuccessfully relaying due to an unhandled exception' do
      stub_request(:post, URL).to_raise StandardError.new('Something went wrong')

      result = @relayer.relay(file_fixture('welcome.eml').read)
      assert_equal '4.0.0', result.status_code
      assert_equal 'Error relaying to ingress: Something went wrong', result.message
      assert_not result.success?
      assert result.failure?
    end
  end
end
