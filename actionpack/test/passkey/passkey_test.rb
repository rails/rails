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
        t.string :aaguid
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

  test "authenticate updates sign count and backed_up" do
    challenge = ActionPack::Passkeys::Passkey.authentication_options(credentials: [ @passkey ]).challenge
    assertion = build_assertion(challenge: challenge, authenticator_data: BACKED_UP_AUTHENTICATOR_DATA)

    @passkey.authenticate(assertion)

    assert_equal 5, @passkey.reload.sign_count
    assert @passkey.backed_up?
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
