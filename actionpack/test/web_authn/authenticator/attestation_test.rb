# frozen_string_literal: true

require_relative "../../web_authn_test_helper"

class ActionPack::WebAuthn::Authenticator::AttestationTest < ActiveSupport::TestCase
  # Attestation object: {"fmt": "none", "attStmt": {}, "authData": <164 bytes>}
  # Auth data contains:
  #   rp_id_hash: SHA-256("example.com") (32 bytes)
  #   flags: 0x41 (user present + attested credential)
  #   sign_count: 42
  #   aaguid: 00010203-0405-0607-0809-0a0b0c0d0e0f (16 bytes)
  #   credential_id: 32 sequential bytes 0x00..0x1f
  #   cose_key: EC2/ES256 P-256 {1: 2, 3: -7, -1: 1, -2: <x>, -3: <y>}
  ATTESTATION_CBOR = [ "a363666d74646e6f6e656761747453746d74a068617574684461746158a4a3" \
    "79a6f6eeafb9a55e378c118034e2751e682fab9f2d30ab13d2125586ce1947410000002a" \
    "000102030405060708090a0b0c0d0e0f0020000102030405060708090a0b0c0d0e0f1011" \
    "12131415161718191a1b1c1d1e1fa50102032620012158202ba472104c686f39d4b623cc" \
    "9324953e7053b47cae818e8cf774203a4f51af7122582069cb8ac519bdd929e2bdbe79e9" \
    "f9b8d14c2d89a7cbd324647a1ccd68b8de3ca0" ].pack("H*")

  CREDENTIAL_ID_BASE64 = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"
  SIGN_COUNT = 42

  test "decodes attestation object" do
    attestation = ActionPack::WebAuthn::Authenticator::Attestation.decode(ATTESTATION_CBOR)

    assert_equal "none", attestation.format
    assert_equal({}, attestation.attestation_statement)
    assert_instance_of ActionPack::WebAuthn::Authenticator::Data, attestation.authenticator_data
  end

  test "delegates credential_id to authenticator_data" do
    attestation = ActionPack::WebAuthn::Authenticator::Attestation.decode(ATTESTATION_CBOR)

    assert_equal CREDENTIAL_ID_BASE64, attestation.credential_id
  end

  test "delegates sign_count to authenticator_data" do
    attestation = ActionPack::WebAuthn::Authenticator::Attestation.decode(ATTESTATION_CBOR)

    assert_equal SIGN_COUNT, attestation.sign_count
  end

  test "delegates public_key to authenticator_data" do
    attestation = ActionPack::WebAuthn::Authenticator::Attestation.decode(ATTESTATION_CBOR)

    assert_instance_of OpenSSL::PKey::EC, attestation.public_key
  end
end
