# frozen_string_literal: true

require "abstract_unit"
require "active_model"
require "active_support/current_attributes"
require "action_pack/web_authn"

ActionPack::WebAuthn.challenge_verifier ||= ActiveSupport::MessageVerifier.new(SecureRandom.hex(64))
ActionPack::WebAuthn.application_name ||= "TestApp"

module WebauthnTestHelper
  # Fixed EC P-256 key pair for WebAuthn tests.
  WEBAUTHN_PRIVATE_KEY = OpenSSL::PKey::EC.new(
    [ "307702010104201dd589de7210b3318620f32150e3012cce021519df1d6e9e01" \
      "0471146d395cdca00a06082a8648ce3d030107a14403420004116847fe19e1ad" \
      "4471ab9980d7ff9cc1e4c7cb7a3af00e082b64fcd84f5ae70114c2495eef16f" \
      "542b5e57dd1b263661624e3cf28f581b57a441edbd756a41d0e" ].pack("H*")
  )

  private
    def webauthn_challenge(purpose: nil)
      ActionPack::WebAuthn::PublicKeyCredential::Options.new(challenge_purpose: purpose).challenge
    end

    def build_credential(id:, transports: [])
      ActionPack::WebAuthn::PublicKeyCredential.new(
        id: id,
        public_key: WEBAUTHN_PRIVATE_KEY,
        sign_count: 0,
        transports: transports
      )
    end

    def webauthn_sign(authenticator_data, client_data_json)
      signed_data = authenticator_data + Digest::SHA256.digest(client_data_json)
      WEBAUTHN_PRIVATE_KEY.sign("SHA256", signed_data)
    end
end
