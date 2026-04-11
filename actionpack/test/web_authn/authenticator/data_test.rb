# frozen_string_literal: true

require_relative "../../web_authn_test_helper"

class ActionPack::WebAuthn::Authenticator::DataTest < ActiveSupport::TestCase
  USER_PRESENT = ActionPack::WebAuthn::Authenticator::Data::USER_PRESENT_FLAG
  USER_VERIFIED = ActionPack::WebAuthn::Authenticator::Data::USER_VERIFIED_FLAG
  BACKUP_ELIGIBLE = ActionPack::WebAuthn::Authenticator::Data::BACKUP_ELIGIBLE_FLAG
  BACKUP_STATE = ActionPack::WebAuthn::Authenticator::Data::BACKUP_STATE_FLAG
  ATTESTED_CREDENTIAL = ActionPack::WebAuthn::Authenticator::Data::ATTESTED_CREDENTIAL_DATA_FLAG

  # Common values:
  #   rp_id_hash: SHA-256("example.com") (32 bytes)
  #   sign_count: 42
  #   aaguid: 00010203-0405-0607-0809-0a0b0c0d0e0f (16 bytes)
  #   credential_id: 32 sequential bytes 0x00..0x1f
  #   cose_key: EC2/ES256 P-256 {1: 2, 3: -7, -1: 1, -2: <x>, -3: <y>}

  RP_ID_HASH = [ "a379a6f6eeafb9a55e378c118034e2751e682fab9f2d30ab13d2125586ce1947" ].pack("H*")
  SIGN_COUNT = 42
  CREDENTIAL_ID_BASE64 = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"

  COSE_KEY_CBOR = [ "a50102032620012158202ba472104c686f39d4b623cc9324953e7053b47cae81" \
    "8e8cf774203a4f51af7122582069cb8ac519bdd929e2bdbe79e9f9b8d14c2d89a7cbd324" \
    "647a1ccd68b8de3ca0" ].pack("H*")

  # rp_id_hash(32) + flags USER_PRESENT + sign_count 42
  AUTH_DATA_NO_CREDENTIAL = [ "a379a6f6eeafb9a55e378c118034e2751e682fab9f2d30ab13d2" \
    "125586ce1947010000002a" ].pack("H*")

  # rp_id_hash(32) + flags USER_PRESENT|ATTESTED_CREDENTIAL + sign_count 42 + aaguid(16) +
  # credential_id_len 32 (2 bytes) + credential_id(32) + cose_key CBOR
  AUTH_DATA_WITH_CREDENTIAL = [ "a379a6f6eeafb9a55e378c118034e2751e682fab9f2d30ab13" \
    "d2125586ce1947410000002a000102030405060708090a0b0c0d0e0f0020000102030405" \
    "060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1fa5010203262001215820" \
    "2ba472104c686f39d4b623cc9324953e7053b47cae818e8cf774203a4f51af7122582069" \
    "cb8ac519bdd929e2bdbe79e9f9b8d14c2d89a7cbd324647a1ccd68b8de3ca0" ].pack("H*")

  # Error test data: ATTESTED_CREDENTIAL flag set but no attested credential data after header
  # rp_id_hash(32) + flags USER_PRESENT|ATTESTED_CREDENTIAL + sign_count 42
  AUTH_DATA_AT_FLAG_NO_CREDENTIAL = [ "a379a6f6eeafb9a55e378c118034e2751e682fab9f2d30" \
    "ab13d2125586ce1947410000002a" ].pack("H*")

  # rp_id_hash(32) + flags USER_PRESENT|ATTESTED_CREDENTIAL + sign_count 0 + aaguid(16), missing credential_id_len
  AUTH_DATA_TRUNCATED_BEFORE_CRED_LEN = [ "a379a6f6eeafb9a55e378c118034e2751e682fab9f" \
    "2d30ab13d2125586ce19474100000000000102030405060708090a0b0c0d0e0f" ].pack("H*")

  # rp_id_hash(32) + flags USER_PRESENT|ATTESTED_CREDENTIAL + sign_count 0 + aaguid(16) + credential_id_len 9999
  AUTH_DATA_HUGE_CRED_LEN = [ "a379a6f6eeafb9a55e378c118034e2751e682fab9f2d30ab13d2" \
    "125586ce19474100000000000102030405060708090a0b0c0d0e0f270f" ].pack("H*")

  test "decodes authenticator data without attested credential" do
    data = ActionPack::WebAuthn::Authenticator::Data.decode(AUTH_DATA_NO_CREDENTIAL)

    assert_equal RP_ID_HASH, data.relying_party_id_hash
    assert_equal USER_PRESENT, data.flags
    assert_equal SIGN_COUNT, data.sign_count
    assert_nil data.credential_id
    assert_nil data.public_key_bytes
  end

  test "decodes authenticator data with attested credential" do
    data = ActionPack::WebAuthn::Authenticator::Data.decode(AUTH_DATA_WITH_CREDENTIAL)

    assert_equal RP_ID_HASH, data.relying_party_id_hash
    assert_equal USER_PRESENT | ATTESTED_CREDENTIAL, data.flags
    assert_equal SIGN_COUNT, data.sign_count
    assert_equal CREDENTIAL_ID_BASE64, data.credential_id
    assert_equal COSE_KEY_CBOR, data.public_key_bytes
  end

  test "user_present? returns true when flag is set" do
    data = build_data_with_flags(USER_PRESENT)
    assert data.user_present?
  end

  test "user_present? returns false when flag is not set" do
    data = build_data_with_flags(0)
    assert_not data.user_present?
  end

  test "user_verified? returns true when flag is set" do
    data = build_data_with_flags(USER_VERIFIED)
    assert data.user_verified?
  end

  test "user_verified? returns false when flag is not set" do
    data = build_data_with_flags(0)
    assert_not data.user_verified?
  end

  test "backup_eligible? returns true when flag is set" do
    data = build_data_with_flags(BACKUP_ELIGIBLE)
    assert data.backup_eligible?
  end

  test "backup_eligible? returns false when flag is not set" do
    data = build_data_with_flags(0)
    assert_not data.backup_eligible?
  end

  test "backed_up? returns true when flag is set" do
    data = build_data_with_flags(BACKUP_STATE)
    assert data.backed_up?
  end

  test "backed_up? returns false when flag is not set" do
    data = build_data_with_flags(0)
    assert_not data.backed_up?
  end

  test "public_key returns OpenSSL key when public_key_bytes present" do
    data = ActionPack::WebAuthn::Authenticator::Data.decode(AUTH_DATA_WITH_CREDENTIAL)

    assert_instance_of OpenSSL::PKey::EC, data.public_key
  end

  test "public_key returns nil when public_key_bytes not present" do
    data = ActionPack::WebAuthn::Authenticator::Data.decode(AUTH_DATA_NO_CREDENTIAL)

    assert_nil data.public_key
  end

  test "raises when attested credential flag set but data truncated before AAGUID" do
    assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      ActionPack::WebAuthn::Authenticator::Data.decode(AUTH_DATA_AT_FLAG_NO_CREDENTIAL)
    end
  end

  test "raises when attested credential flag set but data truncated before credential ID" do
    assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      ActionPack::WebAuthn::Authenticator::Data.decode(AUTH_DATA_TRUNCATED_BEFORE_CRED_LEN)
    end
  end

  test "raises when credential ID length exceeds remaining bytes" do
    assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      ActionPack::WebAuthn::Authenticator::Data.decode(AUTH_DATA_HUGE_CRED_LEN)
    end
  end

  private
    def build_data_with_flags(flags)
      ActionPack::WebAuthn::Authenticator::Data.new(
        bytes: [],
        relying_party_id_hash: RP_ID_HASH,
        flags: flags,
        sign_count: 0,
        credential_id: nil,
        public_key_bytes: nil
      )
    end
end
