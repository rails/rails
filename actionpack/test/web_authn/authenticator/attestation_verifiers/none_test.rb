# frozen_string_literal: true

require_relative "../../../web_authn_test_helper"

class ActionPack::WebAuthn::Authenticator::AttestationVerifiers::NoneTest < ActiveSupport::TestCase
  setup do
    @verifier = ActionPack::WebAuthn::Authenticator::AttestationVerifiers::None.new
  end

  test "verify! passes with nil attestation statement" do
    attestation = Minitest::Mock.new
    attestation.expect :attestation_statement, nil

    assert_nothing_raised do
      @verifier.verify!(attestation, client_data_json: "")
    end
  end

  test "verify! passes with empty attestation statement" do
    attestation = Minitest::Mock.new
    attestation.expect :attestation_statement, {}

    assert_nothing_raised do
      @verifier.verify!(attestation, client_data_json: "")
    end
  end

  test "verify! raises with non-empty attestation statement" do
    attestation = Minitest::Mock.new
    attestation.expect :attestation_statement, { "sig" => "abc" }

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      @verifier.verify!(attestation, client_data_json: "")
    end

    assert_equal "Attestation statement must be empty for 'none' format", error.message
  end
end
