# frozen_string_literal: true

require_relative "../../web_authn_test_helper"

class ActionPack::WebAuthn::PublicKeyCredential::RequestOptionsTest < ActiveSupport::TestCase
  include WebauthnTestHelper

  setup do
    @relying_party = ActionPack::WebAuthn::RelyingParty.new(id: "example.com", name: "Example App")
    @credentials = [
      build_credential(id: "credential-1"),
      build_credential(id: "credential-2")
    ]
    @options = ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(
      credentials: @credentials,
      relying_party: @relying_party
    )
  end

  test "initializes with required parameters" do
    assert_equal @credentials, @options.credentials
    assert_equal @relying_party, @options.relying_party
  end

  test "defaults challenge_purpose to authentication" do
    assert_equal "authentication", @options.challenge_purpose
  end

  test "generates base64url encoded challenge" do
    assert_match(/\A[A-Za-z0-9_-]+\z/, @options.challenge)
  end

  test "generates signed challenge containing nonce" do
    signed_message = Base64.urlsafe_decode64(@options.challenge)
    nonce = ActionPack::WebAuthn.challenge_verifier.verified(signed_message, purpose: "authentication")

    assert_not_nil nonce
    assert_equal 32, Base64.strict_decode64(nonce).bytesize
  end

  test "as_json" do
    json = @options.as_json

    assert_equal @options.challenge, json["challenge"]
    assert_equal "example.com", json["rpId"]
    assert_equal [
      { "type" => "public-key", "id" => "credential-1" },
      { "type" => "public-key", "id" => "credential-2" }
    ], json["allowCredentials"]
    assert_equal "preferred", json["userVerification"]
  end

  test "as_json supports except option" do
    json = @options.as_json(except: :challenge)

    assert_nil json["challenge"]
    assert_not_nil json["rpId"]
  end

  test "as_json includes transports when present" do
    credentials = [
      build_credential(id: "cred-1", transports: [ "usb", "nfc" ]),
      build_credential(id: "cred-2", transports: [ "internal" ])
    ]

    options = ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(
      credentials: credentials,
      relying_party: @relying_party
    )

    assert_equal [
      { "type" => "public-key", "id" => "cred-1", "transports" => [ "usb", "nfc" ] },
      { "type" => "public-key", "id" => "cred-2", "transports" => [ "internal" ] }
    ], options.as_json["allowCredentials"]
  end

  test "as_json omits transports when empty" do
    credentials = [ build_credential(id: "cred-1") ]

    options = ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(
      credentials: credentials,
      relying_party: @relying_party
    )

    assert_equal [
      { "type" => "public-key", "id" => "cred-1" }
    ], options.as_json["allowCredentials"]
  end

  test "as_json renders timeout in milliseconds" do
    assert_equal 300_000, @options.as_json["timeout"]
  end

  test "as_json renders a custom timeout in milliseconds" do
    options = ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(
      credentials: @credentials,
      relying_party: @relying_party,
      timeout: 2.minutes
    )

    assert_equal 120_000, options.as_json["timeout"]
  end

  test "as_json omits timeout when nil" do
    options = ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(
      credentials: @credentials,
      relying_party: @relying_party,
      timeout: nil
    )

    assert_nil options.as_json["timeout"]
  end

  test "as_json omits extensions by default" do
    assert_nil @options.as_json["extensions"]
  end

  test "as_json includes extensions when present" do
    options = ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(
      credentials: @credentials,
      relying_party: @relying_party,
      extensions: { "appid" => "https://example.com" }
    )

    assert_equal({ "appid" => "https://example.com" }, options.as_json["extensions"])
  end

  test "as_json omits hints by default" do
    assert_nil @options.as_json["hints"]
  end

  test "as_json includes hints when present" do
    options = ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(
      credentials: @credentials,
      relying_party: @relying_party,
      hints: [ "client-device" ]
    )

    assert_equal [ "client-device" ], options.as_json["hints"]
  end
end
