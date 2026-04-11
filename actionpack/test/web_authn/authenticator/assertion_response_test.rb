# frozen_string_literal: true

require_relative "../../web_authn_test_helper"

class ActionPack::WebAuthn::Authenticator::AssertionResponseTest < ActiveSupport::TestCase
  include WebauthnTestHelper

  # rp_id_hash("example.com") + flags USER_PRESENT + sign_count 0
  USER_PRESENT_AUTH_DATA = [
    "a379a6f6eeafb9a55e378c118034e2751e682fab9f2d30ab13d2125586ce1947" \
    "0100000000"
  ].pack("H*").freeze

  # rp_id_hash("example.com") + flags USER_PRESENT|USER_VERIFIED + sign_count 0
  USER_PRESENT_AND_VERIFIED_AUTH_DATA = [
    "a379a6f6eeafb9a55e378c118034e2751e682fab9f2d30ab13d2125586ce1947" \
    "0500000000"
  ].pack("H*").freeze

  setup do
    ActionPack::WebAuthn::Current.host = "example.com"

    @challenge = webauthn_challenge(purpose: "authentication")
    @origin = "https://example.com"
    @client_data_json = {
      challenge: @challenge,
      origin: @origin,
      type: "webauthn.get"
    }.to_json

    @credential = Struct.new(:public_key, :sign_count).new(
      WebauthnTestHelper::WEBAUTHN_PRIVATE_KEY, 0
    )

    @response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      client_data_json: @client_data_json,
      authenticator_data: USER_PRESENT_AND_VERIFIED_AUTH_DATA,
      signature: webauthn_sign(USER_PRESENT_AND_VERIFIED_AUTH_DATA, @client_data_json),
      credential: @credential,
      origin: @origin
    )
  end

  test "initializes with credential, authenticator data, and signature" do
    assert_equal @credential, @response.credential
    assert_instance_of ActionPack::WebAuthn::Authenticator::Data, @response.authenticator_data
  end

  test "validate! succeeds with valid challenge, origin, type, and signature" do
    assert_nothing_raised do
      @response.validate!
    end
  end

  test "validate! raises when type is not webauthn.get" do
    client_data_json = {
      challenge: @challenge,
      origin: @origin,
      type: "webauthn.create"
    }.to_json

    response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      client_data_json: client_data_json,
      authenticator_data: USER_PRESENT_AND_VERIFIED_AUTH_DATA,
      signature: webauthn_sign(USER_PRESENT_AND_VERIFIED_AUTH_DATA, client_data_json),
      credential: @credential,
      origin: @origin
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      response.validate!
    end

    assert_equal "Client data type is not webauthn.get", error.message
  end

  test "validate! raises when signature is invalid" do
    response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      client_data_json: @client_data_json,
      authenticator_data: USER_PRESENT_AND_VERIFIED_AUTH_DATA,
      signature: Base64.urlsafe_encode64("invalid-signature", padding: false),
      credential: @credential,
      origin: @origin
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      response.validate!
    end

    assert_equal "Invalid signature", error.message
  end

  test "validate! raises when challenge has expired" do
    expired_challenge = ActionPack::WebAuthn::PublicKeyCredential::Options.new(
      challenge_expiration: 0.seconds,
      challenge_purpose: "authentication"
    ).challenge

    travel 1.second do
      client_data_json = {
        challenge: expired_challenge,
        origin: @origin,
        type: "webauthn.get"
      }.to_json

      response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
        client_data_json: client_data_json,
        authenticator_data: USER_PRESENT_AND_VERIFIED_AUTH_DATA,
        signature: webauthn_sign(USER_PRESENT_AND_VERIFIED_AUTH_DATA, client_data_json),
        credential: @credential,
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

  test "validate! succeeds with user_verification preferred when not verified" do
    response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      client_data_json: @client_data_json,
      authenticator_data: USER_PRESENT_AUTH_DATA,
      signature: webauthn_sign(USER_PRESENT_AUTH_DATA, @client_data_json),
      credential: @credential,
      origin: @origin,
      user_verification: :preferred
    )

    assert_nothing_raised do
      response.validate!
    end
  end

  test "validate! succeeds with user_verification required when verified" do
    response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      client_data_json: @client_data_json,
      authenticator_data: USER_PRESENT_AND_VERIFIED_AUTH_DATA,
      signature: webauthn_sign(USER_PRESENT_AND_VERIFIED_AUTH_DATA, @client_data_json),
      credential: @credential,
      origin: @origin,
      user_verification: :required
    )

    assert_nothing_raised do
      response.validate!
    end
  end

  test "validate! raises with user_verification required when not verified" do
    response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      client_data_json: @client_data_json,
      authenticator_data: USER_PRESENT_AUTH_DATA,
      signature: webauthn_sign(USER_PRESENT_AUTH_DATA, @client_data_json),
      credential: @credential,
      origin: @origin,
      user_verification: :required
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      response.validate!
    end

    assert_equal "User verification is required", error.message
  end
end
