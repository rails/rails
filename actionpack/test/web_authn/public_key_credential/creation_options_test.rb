# frozen_string_literal: true

require_relative "../../web_authn_test_helper"

class ActionPack::WebAuthn::PublicKeyCredential::CreationOptionsTest < ActiveSupport::TestCase
  include WebauthnTestHelper

  setup do
    @relying_party = ActionPack::WebAuthn::RelyingParty.new(id: "example.com", name: "Example App")
    @options = ActionPack::WebAuthn::PublicKeyCredential::CreationOptions.new(
      id: "user-123",
      name: "user@example.com",
      display_name: "Test User",
      relying_party: @relying_party
    )
  end

  test "initializes with required parameters" do
    assert_equal "user-123", @options.id
    assert_equal "user@example.com", @options.name
    assert_equal "Test User", @options.display_name
    assert_equal @relying_party, @options.relying_party
  end

  test "defaults challenge_purpose to registration" do
    assert_equal "registration", @options.challenge_purpose
  end

  test "generates base64url encoded challenge" do
    assert_match(/\A[A-Za-z0-9_-]+\z/, @options.challenge)
  end

  test "generates signed challenge containing nonce" do
    signed_message = Base64.urlsafe_decode64(@options.challenge)
    nonce = ActionPack::WebAuthn.challenge_verifier.verified(signed_message, purpose: "registration")

    assert_not_nil nonce
    assert_equal 32, Base64.strict_decode64(nonce).bytesize
  end

  test "as_json" do
    json = @options.as_json

    assert_equal @options.challenge, json["challenge"]

    assert_equal({ "id" => "example.com", "name" => "Example App" }, json["rp"])

    user = json["user"]
    assert_equal Base64.urlsafe_encode64("user-123", padding: false), user["id"]
    assert_equal "user@example.com", user["name"]
    assert_equal "Test User", user["displayName"]

    assert_equal [
      { "type" => "public-key", "alg" => -7 },
      { "type" => "public-key", "alg" => -8 },
      { "type" => "public-key", "alg" => -257 }
    ], json["pubKeyCredParams"]

    assert_equal "required", json["authenticatorSelection"]["residentKey"]
    assert_equal true, json["authenticatorSelection"]["requireResidentKey"]
    assert_equal "preferred", json["authenticatorSelection"]["userVerification"]
  end

  test "as_json supports except option" do
    json = @options.as_json(except: :challenge)

    assert_nil json["challenge"]
    assert_not_nil json["rp"]
  end

  test "as_json includes residentKey in authenticatorSelection" do
    options = ActionPack::WebAuthn::PublicKeyCredential::CreationOptions.new(
      id: "user-123",
      name: "user@example.com",
      display_name: "Test User",
      resident_key: :required,
      relying_party: @relying_party
    )

    assert_equal "required", options.as_json["authenticatorSelection"]["residentKey"]
    assert_equal true, options.as_json["authenticatorSelection"]["requireResidentKey"]
  end

  test "as_json excludes excludeCredentials when empty" do
    assert_nil @options.as_json["excludeCredentials"]
  end

  test "as_json includes excludeCredentials" do
    credentials = [
      build_credential(id: "cred-1", transports: [ "usb", "nfc" ]),
      build_credential(id: "cred-2", transports: [ "internal" ])
    ]

    options = ActionPack::WebAuthn::PublicKeyCredential::CreationOptions.new(
      id: "user-123",
      name: "user@example.com",
      display_name: "Test User",
      exclude_credentials: credentials,
      relying_party: @relying_party
    )

    assert_equal [
      { "type" => "public-key", "id" => "cred-1", "transports" => [ "usb", "nfc" ] },
      { "type" => "public-key", "id" => "cred-2", "transports" => [ "internal" ] }
    ], options.as_json["excludeCredentials"]
  end

  test "as_json includes attestation none by default" do
    assert_equal "none", @options.as_json["attestation"]
  end

  test "as_json includes attestation when not none" do
    options = ActionPack::WebAuthn::PublicKeyCredential::CreationOptions.new(
      id: "user-123",
      name: "user@example.com",
      display_name: "Test User",
      attestation: :direct,
      relying_party: @relying_party
    )

    assert_equal "direct", options.as_json["attestation"]
  end

  test "raises with invalid attestation preference" do
    assert_raises(ActionPack::WebAuthn::InvalidOptionsError) do
      ActionPack::WebAuthn::PublicKeyCredential::CreationOptions.new(
        id: "user-123",
        name: "user@example.com",
        display_name: "Test User",
        attestation: :invalid,
        relying_party: @relying_party
      )
    end
  end

  test "as_json excludeCredentials omits transports when empty" do
    options = ActionPack::WebAuthn::PublicKeyCredential::CreationOptions.new(
      id: "user-123",
      name: "user@example.com",
      display_name: "Test User",
      exclude_credentials: [ build_credential(id: "cred-1") ],
      relying_party: @relying_party
    )

    assert_equal [
      { "type" => "public-key", "id" => "cred-1" }
    ], options.as_json["excludeCredentials"]
  end

  test "as_json omits authenticatorAttachment by default" do
    assert_nil @options.as_json["authenticatorSelection"]["authenticatorAttachment"]
  end

  test "as_json includes authenticatorAttachment when set" do
    options = build_options(authenticator_attachment: "platform")

    assert_equal "platform", options.as_json["authenticatorSelection"]["authenticatorAttachment"]
  end

  test "raises with invalid authenticatorAttachment" do
    assert_raises(ActionPack::WebAuthn::InvalidOptionsError) do
      build_options(authenticator_attachment: "invalid")
    end
  end

  test "as_json renders timeout in milliseconds" do
    assert_equal 600_000, @options.as_json["timeout"]
  end

  test "as_json renders a custom timeout in milliseconds" do
    assert_equal 120_000, build_options(timeout: 2.minutes).as_json["timeout"]
  end

  test "as_json renders a sub-second timeout as integer milliseconds" do
    json = build_options(timeout: 0.5).as_json

    assert_equal 500, json["timeout"]
    assert_kind_of Integer, json["timeout"]
  end

  test "as_json omits timeout when nil" do
    assert_nil build_options(timeout: nil).as_json["timeout"]
  end

  test "as_json omits extensions by default" do
    assert_nil @options.as_json["extensions"]
  end

  test "as_json includes extensions when present" do
    json = build_options(extensions: { "credProps" => true }).as_json

    assert_equal({ "credProps" => true }, json["extensions"])
  end

  test "as_json omits hints and attestationFormats by default" do
    json = @options.as_json

    assert_nil json["hints"]
    assert_nil json["attestationFormats"]
  end

  test "as_json includes hints and attestationFormats when present" do
    json = build_options(hints: [ "security-key" ], attestation_formats: [ "packed" ]).as_json

    assert_equal [ "security-key" ], json["hints"]
    assert_equal [ "packed" ], json["attestationFormats"]
  end

  private
    def build_options(**overrides)
      ActionPack::WebAuthn::PublicKeyCredential::CreationOptions.new(
        id: "user-123",
        name: "user@example.com",
        display_name: "Test User",
        relying_party: @relying_party,
        **overrides
      )
    end
end
