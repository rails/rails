# frozen_string_literal: true

require_relative "../../web_authn_test_helper"

class ActionPack::WebAuthn::Authenticator::ResponseTest < ActiveSupport::TestCase
  include WebauthnTestHelper

  # rp_id_hash("example.com") + flags 0x05 (UP+UV) + sign_count 0
  AUTHENTICATOR_DATA_BYTES = [
    "a379a6f6eeafb9a55e378c118034e2751e682fab9f2d30ab13d2125586ce1947" \
    "0500000000"
  ].pack("H*").freeze

  # rp_id_hash("evil.com") + flags 0x05 (UP+UV) + sign_count 0
  WRONG_RP_AUTHENTICATOR_DATA_BYTES = [
    "1867b49abe26b512d11cb45294e41afa6f728697705714911c5c001179f7f2bb" \
    "0500000000"
  ].pack("H*").freeze

  class TestableResponse < ActionPack::WebAuthn::Authenticator::Response
    attr_reader :authenticator_data

    def initialize(authenticator_data:, **attrs)
      super(**attrs)
      @authenticator_data = authenticator_data
    end
  end

  setup do
    ActionPack::WebAuthn::Current.host = "example.com"

    @challenge = webauthn_challenge
    @origin = "https://example.com"
    @client_data_json = {
      challenge: @challenge,
      origin: @origin,
      type: "webauthn.create"
    }.to_json

    @authenticator_data = ActionPack::WebAuthn::Authenticator::Data.decode(AUTHENTICATOR_DATA_BYTES)
    @response = TestableResponse.new(
      client_data_json: @client_data_json,
      authenticator_data: @authenticator_data,
      origin: @origin
    )
  end

  test "parses client data JSON" do
    assert_equal @challenge, @response.client_data["challenge"]
    assert_equal @origin, @response.client_data["origin"]
  end

  test "valid? returns true when challenge and origin match" do
    assert @response.valid?
  end

  test "valid? returns false when challenge is missing" do
    client_data_json = { origin: @origin, type: "webauthn.create" }.to_json

    response = TestableResponse.new(
      client_data_json: client_data_json,
      authenticator_data: @authenticator_data,
      origin: @origin
    )

    assert_not response.valid?
  end

  test "valid? returns false when origin does not match" do
    @response.origin = "https://evil.com"
    assert_not @response.valid?
  end

  test "validate! raises when challenge has expired" do
    expired_challenge = ActionPack::WebAuthn::PublicKeyCredential::Options.new(
      challenge_expiration: 0.seconds
    ).challenge

    travel 1.second do
      client_data_json = {
        challenge: expired_challenge,
        origin: @origin,
        type: "webauthn.create"
      }.to_json

      response = TestableResponse.new(
        client_data_json: client_data_json,
        authenticator_data: @authenticator_data,
        origin: @origin
      )

      error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
        response.validate!
      end

      assert_equal "Challenge has expired", error.message
    end
  end

  test "validate! raises when origin does not match" do
    @response.origin = "https://evil.com"

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      @response.validate!
    end

    assert_equal "Origin does not match", error.message
  end

  test "validate! raises when crossOrigin is true" do
    client_data_json = {
      challenge: @challenge,
      origin: @origin,
      type: "webauthn.create",
      crossOrigin: true
    }.to_json

    response = TestableResponse.new(
      client_data_json: client_data_json,
      authenticator_data: @authenticator_data,
      origin: @origin
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      response.validate!
    end

    assert_equal "Cross-origin requests are not supported", error.message
  end

  test "validate! raises when relying party ID does not match" do
    wrong_rp_data = ActionPack::WebAuthn::Authenticator::Data.decode(WRONG_RP_AUTHENTICATOR_DATA_BYTES)

    response = TestableResponse.new(
      client_data_json: @client_data_json,
      authenticator_data: wrong_rp_data,
      origin: @origin
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      response.validate!
    end

    assert_equal "Relying party ID does not match", error.message
  end

  test "validate! raises when tokenBinding status is present" do
    client_data_json = {
      challenge: @challenge,
      origin: @origin,
      type: "webauthn.create",
      tokenBinding: { status: "present", id: "some-id" }
    }.to_json

    response = TestableResponse.new(
      client_data_json: client_data_json,
      authenticator_data: @authenticator_data,
      origin: @origin
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      response.validate!
    end

    assert_equal "Token binding is not supported", error.message
  end
end
