# frozen_string_literal: true

require_relative "../web_authn_test_helper"
require "active_record"
require "action_pack/passkeys"

class PasskeyApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

ActionPack::Passkeys.parent_class_name = "PasskeyApplicationRecord"

require_relative "../../lib/passkeys/app/models/action_pack/passkeys/passkey"

ActionPack::Passkeys::Passkey.table_name = "action_pack_passkeys_passkeys"

class PasskeyUser < PasskeyApplicationRecord
  include ActionPack::Passkeys::Holder

  self.table_name = "users"
  has_passkeys name: :name, display_name: :name
end

class ActionPack::Passkeys::PasskeyTest < ActiveSupport::TestCase
  include WebauthnTestHelper

  CREDENTIAL_ID = Base64.urlsafe_encode64("\x01" * 32, padding: false).freeze
  PUBLIC_KEY_DER = WebauthnTestHelper::WEBAUTHN_PRIVATE_KEY.public_to_der.freeze

  # rp_id_hash(32) + flags 0x05 (UP+UV) + sign_count 1
  AUTHENTICATOR_DATA = [
    "80fc0fb9266db7b83f85850fa0e6548b6d70ee68c8b5b412f1deea6ebdef0404" \
    "0500000001"
  ].pack("H*").freeze

  # rp_id_hash(32) + flags 0x1D (UP+UV+BE+BS) + sign_count 5
  BACKED_UP_AUTHENTICATOR_DATA = [
    "80fc0fb9266db7b83f85850fa0e6548b6d70ee68c8b5b412f1deea6ebdef0404" \
    "1d00000005"
  ].pack("H*").freeze

  # {"fmt": "none", "attStmt": {}, "authData": rp_id_hash=SHA-256("example.com"),
  #  flags: 0x45 (UP+UV+AT), aaguid 00010203-..., credential_id 0x00..0x1f, ES256 key}
  ATTESTATION_NONE_VERIFIED = [ "a363666d74646e6f6e656761747453746d74a068617574684461" \
    "746158a4a379a6f6eeafb9a55e378c118034e2751e682fab9f2d30ab13d2125586ce1947" \
    "4500000000000102030405060708090a0b0c0d0e0f0020000102030405060708090a0b0c" \
    "0d0e0f101112131415161718191a1b1c1d1e1fa50102032620012158202ba472104c686f" \
    "39d4b623cc9324953e7053b47cae818e8cf774203a4f51af7122582069cb8ac519bdd929" \
    "e2bdbe79e9f9b8d14c2d89a7cbd324647a1ccd68b8de3ca0" ].pack("H*").freeze

  setup do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Schema.define do
      create_table :users, id: :string, force: true do |t|
        t.string :name
      end

      create_table :action_pack_passkeys_passkeys, id: :string, force: true do |t|
        t.string :holder_id, null: false
        t.string :holder_type, null: false
        t.string :credential_id, null: false
        t.binary :public_key, null: false
        t.integer :sign_count, null: false, default: 0
        t.string :name
        t.text :transports
        t.string :relying_party_id
        t.string :aaguid
        t.boolean :backup_eligible
        t.boolean :backed_up

        t.timestamps

        t.index [ :holder_type, :holder_id ]
        t.index :credential_id, unique: true
      end
    end

    @user = PasskeyUser.create!(id: SecureRandom.uuid, name: "Kevin")

    ActionPack::WebAuthn::Current.host = "www.example.com"
    ActionPack::WebAuthn::Current.origin = "http://www.example.com"

    @passkey = @user.passkeys.create!(
      id: SecureRandom.uuid,
      credential_id: CREDENTIAL_ID,
      public_key: PUBLIC_KEY_DER,
      sign_count: 0,
      transports: [ "internal" ]
    )
  end

  test "authenticate with valid assertion" do
    challenge = ActionPack::Passkeys::Passkey.authentication_options(credentials: [ @passkey ]).challenge
    assertion = build_assertion(challenge: challenge, authenticator_data: AUTHENTICATOR_DATA)

    result = @passkey.authenticate(assertion)

    assert_equal @passkey, result
  end

  test "authenticate returns nil with invalid signature" do
    challenge = ActionPack::Passkeys::Passkey.authentication_options(credentials: [ @passkey ]).challenge
    assertion = build_assertion(challenge: challenge, authenticator_data: AUTHENTICATOR_DATA)
    assertion[:signature] = Base64.urlsafe_encode64("invalid", padding: false)

    assert_nil @passkey.authenticate(assertion)
  end

  test "authenticate! raises with invalid signature" do
    challenge = ActionPack::Passkeys::Passkey.authentication_options(credentials: [ @passkey ]).challenge
    assertion = build_assertion(challenge: challenge, authenticator_data: AUTHENTICATOR_DATA)
    assertion[:signature] = Base64.urlsafe_encode64("invalid", padding: false)

    assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      @passkey.authenticate!(assertion)
    end
  end

  test "class authenticate! raises RecordNotFound for an unknown credential" do
    challenge = ActionPack::Passkeys::Passkey.authentication_options(credentials: [ @passkey ]).challenge
    assertion = build_assertion(challenge: challenge, authenticator_data: AUTHENTICATOR_DATA)
    assertion[:id] = Base64.urlsafe_encode64("\x02" * 32, padding: false)

    assert_raises(ActiveRecord::RecordNotFound) do
      ActionPack::Passkeys::Passkey.authenticate!(assertion)
    end
  end

  test "authenticate updates sign count and backed_up" do
    challenge = ActionPack::Passkeys::Passkey.authentication_options(credentials: [ @passkey ]).challenge
    assertion = build_assertion(challenge: challenge, authenticator_data: BACKED_UP_AUTHENTICATOR_DATA)

    @passkey.authenticate(assertion)

    assert_equal 5, @passkey.reload.sign_count
    assert @passkey.backed_up?
  end

  test "register persists relying_party_id and backup_eligible" do
    ActionPack::WebAuthn::Current.host = "example.com"
    ActionPack::WebAuthn::Current.origin = "https://example.com"

    challenge = ActionPack::Passkeys::Passkey.registration_options(holder: @user).challenge
    client_data_json = { challenge: challenge, origin: "https://example.com", type: "webauthn.create" }.to_json

    passkey = @user.passkeys.register(
      {
        client_data_json: client_data_json,
        attestation_object: Base64.urlsafe_encode64(ATTESTATION_NONE_VERIFIED, padding: false),
        transports: [ "internal" ]
      },
      id: SecureRandom.uuid
    )

    assert_equal "example.com", passkey.relying_party_id
    assert_equal false, passkey.backup_eligible
  end

  test "register returns nil with invalid attestation" do
    ActionPack::WebAuthn::Current.host = "example.com"
    ActionPack::WebAuthn::Current.origin = "https://example.com"

    invalid = {
      client_data_json: { challenge: "invalid", origin: "https://example.com", type: "webauthn.create" }.to_json,
      attestation_object: Base64.urlsafe_encode64(ATTESTATION_NONE_VERIFIED, padding: false),
      transports: [ "internal" ]
    }

    assert_no_difference -> { ActionPack::Passkeys::Passkey.count } do
      assert_nil @user.passkeys.register(invalid, id: SecureRandom.uuid)
    end
  end

  test "register! raises with invalid attestation" do
    ActionPack::WebAuthn::Current.host = "example.com"
    ActionPack::WebAuthn::Current.origin = "https://example.com"

    invalid = {
      client_data_json: { challenge: "invalid", origin: "https://example.com", type: "webauthn.create" }.to_json,
      attestation_object: Base64.urlsafe_encode64(ATTESTATION_NONE_VERIFIED, padding: false),
      transports: [ "internal" ]
    }

    assert_no_difference -> { ActionPack::Passkeys::Passkey.count } do
      assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
        @user.passkeys.register!(invalid, id: SecureRandom.uuid)
      end
    end
  end

  test "to_public_key_credential" do
    credential = @passkey.to_public_key_credential

    assert_equal @passkey.credential_id, credential.id
    assert_equal @passkey.sign_count, credential.sign_count
    assert_equal @passkey.transports, credential.transports
  end

  private
    def build_assertion(challenge:, authenticator_data:)
      client_data_json = { challenge: challenge, origin: "http://www.example.com", type: "webauthn.get" }.to_json

      {
        id: @passkey.credential_id,
        client_data_json: client_data_json,
        authenticator_data: Base64.urlsafe_encode64(authenticator_data, padding: false),
        signature: Base64.urlsafe_encode64(webauthn_sign(authenticator_data, client_data_json), padding: false)
      }
    end
end
