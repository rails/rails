# frozen_string_literal: true

require_relative "../web_authn_test_helper"

class ActionPack::WebAuthn::RelyingPartyTest < ActiveSupport::TestCase
  test "initializes with explicit id and name" do
    relying_party = ActionPack::WebAuthn::RelyingParty.new(id: "example.com", name: "Example App")

    assert_equal "example.com", relying_party.id
    assert_equal "Example App", relying_party.name
  end

  test "initializes with default id from Current.host" do
    ActionPack::WebAuthn::Current.set(host: "default.example.com") do
      relying_party = ActionPack::WebAuthn::RelyingParty.new(name: "Example App")

      assert_equal "default.example.com", relying_party.id
    end
  end

  test "initializes with default id from configured relying_party_id" do
    ActionPack::WebAuthn.relying_party_id = "configured.example.com"

    ActionPack::WebAuthn::Current.set(host: "request.example.com") do
      relying_party = ActionPack::WebAuthn::RelyingParty.new(name: "Example App")

      assert_equal "configured.example.com", relying_party.id
    end
  ensure
    ActionPack::WebAuthn.relying_party_id = nil
  end

  test "explicit id takes precedence over configured relying_party_id" do
    ActionPack::WebAuthn.relying_party_id = "configured.example.com"

    relying_party = ActionPack::WebAuthn::RelyingParty.new(id: "explicit.example.com")

    assert_equal "explicit.example.com", relying_party.id
  ensure
    ActionPack::WebAuthn.relying_party_id = nil
  end

  test "initializes with default name from application_name" do
    relying_party = ActionPack::WebAuthn::RelyingParty.new(id: "example.com")

    assert_equal ActionPack::WebAuthn.application_name, relying_party.name
  end

  test "as_json returns id and name" do
    relying_party = ActionPack::WebAuthn::RelyingParty.new(id: "example.com", name: "Example App")

    assert_equal({ id: "example.com", name: "Example App" }, relying_party.as_json)
  end
end
