# frozen_string_literal: true

require_relative "../web_authn_test_helper"

class ActionPack::WebAuthn::CoseKeyTest < ActiveSupport::TestCase
  module FakeKeyFormat
    ALGORITHM = -65535

    class << self
      def algorithm
        ALGORITHM
      end

      def to_public_key_credential_param
        { type: "public-key", alg: algorithm }
      end

      def build(cose_key)
        :fake_openssl_key
      end
    end
  end

  # EC2/ES256 P-256 public key (32-byte x and y coordinates)
  EC2_X = [ "2ba472104c686f39d4b623cc9324953e7053b47cae818e8cf774203a4f51af71" ].pack("H*")
  EC2_Y = [ "69cb8ac519bdd929e2bdbe79e9f9b8d14c2d89a7cbd324647a1ccd68b8de3ca0" ].pack("H*")

  # CBOR: {1: 2, 3: -7, -1: 1, -2: <x 32 bytes>, -3: <y 32 bytes>}
  EC2_CBOR = [ "a50102032620012158202ba472104c686f39d4b623cc9324953e7053b47cae81" \
    "8e8cf774203a4f51af7122582069cb8ac519bdd929e2bdbe79e9f9b8d14c2d89a7cbd324" \
    "647a1ccd68b8de3ca0" ].pack("H*")

  # Ed25519 public key (32 bytes)
  ED25519_X = [ "a95ee02872a2c5224b394832767bea746620e50776e845872228716065f16005" ].pack("H*")

  # CBOR: {1: 1, 3: -8, -1: 6, -2: <x 32 bytes>}
  OKP_CBOR = [ "a4010103272006215820a95ee02872a2c5224b394832767bea746620e50776e8" \
    "45872228716065f16005" ].pack("H*")

  # RSA 2048-bit public key (256-byte modulus, 3-byte exponent 65537)
  RSA_N = [ "d388adb3aa7812402281c57ce870821b17558f0a247a771834892d85399ecd4f" \
    "830dd35f65e7afe5030d9ee10f4873567039976486202cce8ac499114194d32fe615026e" \
    "7eeee5b2ff564041d68b9b33c35a2ac17210c69c9e85fa74249b06e4ffa6b38ff5ef54e" \
    "1860aa59a6fb043e2b65ecf0ce8d0ff90d25683ca2da016618308f3fa7f74efc178ec46" \
    "e0224f10cf0eed7d46cc6167210f088cc6b77fc08a7fcd14536aa9c726519806a96ea00" \
    "517ce1ed1336ae6962338a6c4cc4754d953ebbffb5d6b1bc76368b552b628adb788b0bc" \
    "9f895dff6b1c74d79ce210b5941995beb1f498a1e9123666bdc92bc6b0f2a04fdb40cf1" \
    "d253ba1582673ec293113" ].pack("H*")
  RSA_E = [ "010001" ].pack("H*")

  # CBOR: {1: 3, 3: -257, -1: <n 256 bytes>, -2: <e 3 bytes>}
  RSA_CBOR = [ "a401030339010020590100d388adb3aa7812402281c57ce870821b17558f0a24" \
    "7a771834892d85399ecd4f830dd35f65e7afe5030d9ee10f4873567039976486202cce8a" \
    "c499114194d32fe615026e7eeee5b2ff564041d68b9b33c35a2ac17210c69c9e85fa742" \
    "49b06e4ffa6b38ff5ef54e1860aa59a6fb043e2b65ecf0ce8d0ff90d25683ca2da01661" \
    "8308f3fa7f74efc178ec46e0224f10cf0eed7d46cc6167210f088cc6b77fc08a7fcd145" \
    "36aa9c726519806a96ea00517ce1ed1336ae6962338a6c4cc4754d953ebbffb5d6b1bc7" \
    "6368b552b628adb788b0bc9f895dff6b1c74d79ce210b5941995beb1f498a1e9123666b" \
    "dc92bc6b0f2a04fdb40cf1d253ba1582673ec2931132143010001" ].pack("H*")

  setup do
    @ec2_parameters = {
      1 => 2,    # kty: EC2
      3 => -7,   # alg: ES256
      -1 => 1,   # crv: P-256
      -2 => EC2_X,
      -3 => EC2_Y
    }

    @rsa_parameters = {
      1 => 3,     # kty: RSA
      3 => -257,  # alg: RS256
      -1 => RSA_N,
      -2 => RSA_E
    }

    @okp_parameters = {
      1 => 1,    # kty: OKP
      3 => -8,   # alg: EdDSA
      -1 => 6,   # crv: Ed25519
      -2 => ED25519_X
    }
  end

  test "initializes with key type, algorithm, and parameters" do
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 2,
      algorithm: -7,
      parameters: @ec2_parameters
    )

    assert_equal 2, key.key_type
    assert_equal(-7, key.algorithm)
    assert_equal @ec2_parameters, key.parameters
  end

  test "decodes EC2/ES256 key from CBOR" do
    key = ActionPack::WebAuthn::CoseKey.decode(EC2_CBOR)

    assert_equal 2, key.key_type
    assert_equal(-7, key.algorithm)
  end

  test "decodes OKP/EdDSA key from CBOR" do
    key = ActionPack::WebAuthn::CoseKey.decode(OKP_CBOR)

    assert_equal 1, key.key_type
    assert_equal(-8, key.algorithm)
  end

  test "decodes RSA/RS256 key from CBOR" do
    key = ActionPack::WebAuthn::CoseKey.decode(RSA_CBOR)

    assert_equal 3, key.key_type
    assert_equal(-257, key.algorithm)
  end

  test "converts EC2/ES256 key to OpenSSL EC key" do
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 2,
      algorithm: -7,
      parameters: @ec2_parameters
    )

    openssl_key = key.to_openssl_key

    assert_instance_of OpenSSL::PKey::EC, openssl_key
    assert_equal "prime256v1", openssl_key.group.curve_name
  end

  test "converts OKP/EdDSA key to OpenSSL Ed25519 key" do
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 1,
      algorithm: -8,
      parameters: @okp_parameters
    )

    openssl_key = key.to_openssl_key

    assert_equal "ED25519", openssl_key.oid
  end

  test "converts RSA/RS256 key to OpenSSL RSA key" do
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 3,
      algorithm: -257,
      parameters: @rsa_parameters
    )

    openssl_key = key.to_openssl_key

    assert_instance_of OpenSSL::PKey::RSA, openssl_key
    assert_equal 65537, openssl_key.e.to_i
  end

  test "raises error for mismatched key type" do
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 99,
      algorithm: -7,
      parameters: {}
    )

    error = assert_raises(ActionPack::WebAuthn::UnsupportedKeyTypeError) do
      key.to_openssl_key
    end

    assert_match(/key type/i, error.message)
    assert_match(/99/, error.message)
  end

  test "raises error for unregistered algorithm" do
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 2,
      algorithm: -65536,
      parameters: {}
    )

    error = assert_raises(ActionPack::WebAuthn::UnsupportedKeyTypeError) do
      key.to_openssl_key
    end

    assert_match(/Unsupported COSE algorithm: -65536/, error.message)
  end

  test "registering a custom key format makes to_openssl_key dispatch to it" do
    ActionPack::WebAuthn.register_key_format(FakeKeyFormat)

    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 42,
      algorithm: FakeKeyFormat.algorithm,
      parameters: {}
    )

    assert_equal :fake_openssl_key, key.to_openssl_key
  ensure
    ActionPack::WebAuthn.key_formats.delete(FakeKeyFormat.algorithm)
  end

  test "raises error for unsupported OKP curve" do
    parameters = @okp_parameters.merge(-1 => 5) # Ed448 instead of Ed25519
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 1,
      algorithm: -8,
      parameters: parameters
    )

    error = assert_raises(ActionPack::WebAuthn::UnsupportedKeyTypeError) do
      key.to_openssl_key
    end

    assert_match(/curve/, error.message.downcase)
  end

  test "raises error for unsupported EC curve" do
    parameters = @ec2_parameters.merge(-1 => 2) # P-384 instead of P-256
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 2,
      algorithm: -7,
      parameters: parameters
    )

    error = assert_raises(ActionPack::WebAuthn::UnsupportedKeyTypeError) do
      key.to_openssl_key
    end

    assert_match(/curve/, error.message.downcase)
  end

  test "raises error for EC2 key with missing coordinates" do
    parameters = @ec2_parameters.except(-3) # missing y coordinate
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 2,
      algorithm: -7,
      parameters: parameters
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidKeyError) do
      key.to_openssl_key
    end

    assert_match(/missing ec2 key coordinates/i, error.message)
  end

  test "raises error for EC2 key with wrong coordinate length" do
    parameters = @ec2_parameters.merge(-2 => "\x00" * 16) # 16 bytes instead of 32
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 2,
      algorithm: -7,
      parameters: parameters
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidKeyError) do
      key.to_openssl_key
    end

    assert_match(/invalid ec2 coordinate length/i, error.message)
  end

  test "raises error for OKP key with missing coordinate" do
    parameters = @okp_parameters.except(-2) # missing x coordinate
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 1,
      algorithm: -8,
      parameters: parameters
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidKeyError) do
      key.to_openssl_key
    end

    assert_match(/missing okp key coordinate/i, error.message)
  end

  test "raises error for RSA key with missing parameters" do
    parameters = @rsa_parameters.except(-1) # missing n
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 3,
      algorithm: -257,
      parameters: parameters
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidKeyError) do
      key.to_openssl_key
    end

    assert_match(/missing rsa key parameters/i, error.message)
  end

  test "raises error for RSA key smaller than 2048 bits" do
    small_n = "\x01" + ("\x00" * 127) # 1024-bit modulus
    parameters = @rsa_parameters.merge(-1 => small_n)
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 3,
      algorithm: -257,
      parameters: parameters
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidKeyError) do
      key.to_openssl_key
    end

    assert_match(/at least 2048 bits/i, error.message)
  end
end
