# frozen_string_literal: true

module ActionPack
  module WebAuthn
    # = Action Pack WebAuthn COSE Key
    #
    # Parses COSE (CBOR Object Signing and Encryption) public keys as specified in
    # RFC 9053[https://datatracker.ietf.org/doc/html/rfc9053]. WebAuthn authenticators
    # return public keys in COSE format, which must be converted to a standard format
    # for signature verification.
    #
    # == Usage
    #
    #   # Decode a COSE key from CBOR bytes (e.g., from authenticator data)
    #   cose_key = ActionPack::WebAuthn::CoseKey.decode(cbor_bytes)
    #
    #   # Convert to OpenSSL key for signature verification
    #   openssl_key = cose_key.to_openssl_key
    #   openssl_key.verify("SHA256", signature, signed_data)
    #
    # == Supported Algorithms
    #
    # [ES256]
    #   ECDSA with P-256 curve and SHA-256. The most common algorithm for WebAuthn.
    #
    # [EdDSA]
    #   EdDSA with Ed25519 curve. Increasingly supported by modern authenticators.
    #
    # [RS256]
    #   RSASSA-PKCS1-v1_5 with SHA-256. Used by some security keys and platforms.
    #
    # == Attributes
    #
    # [+key_type+]
    #   The COSE key type (1 for OKP, 2 for EC2, 3 for RSA).
    #
    # [+algorithm+]
    #   The COSE algorithm identifier (-7 for ES256, -8 for EdDSA, -257 for RS256).
    #
    # [+parameters+]
    #   The full COSE key parameters map, including curve and coordinate data.
    class CoseKey
      P256_COORDINATE_LENGTH = 32
      MINIMUM_RSA_KEY_BITS = 2048

      # COSE key labels
      KEY_TYPE_LABEL = 1
      ALGORITHM_LABEL = 3
      EC2_CURVE_LABEL = -1
      EC2_X_LABEL = -2
      EC2_Y_LABEL = -3
      RSA_N_LABEL = -1
      RSA_E_LABEL = -2
      OKP_CURVE_LABEL = -1
      OKP_X_LABEL = -2

      # COSE key types
      OKP = 1
      EC2 = 2
      RSA = 3

      # COSE algorithms
      ES256 = -7
      EDDSA = -8
      RS256 = -257

      # COSE EC2 curves
      P256 = 1

      # COSE OKP curves
      ED25519 = 6

      # OpenSSL types
      UNCOMPRESSED_POINT_MARKER = 0x04

      attr_reader :key_type, :algorithm, :parameters

      class << self
        # Decodes a COSE key from CBOR-encoded bytes.
        #
        #   cose_key = ActionPack::WebAuthn::CoseKey.decode(cbor_bytes)
        #   cose_key.algorithm # => -7 (ES256)
        def decode(bytes)
          data = ActionPack::WebAuthn::CborDecoder.decode(bytes)
          new(
            key_type: data[KEY_TYPE_LABEL],
            algorithm: data[ALGORITHM_LABEL],
            parameters: data
          )
        end
      end

      def initialize(key_type:, algorithm:, parameters:) # :nodoc:
        @key_type = key_type
        @algorithm = algorithm
        @parameters = parameters
      end

      # Converts the COSE key to an OpenSSL public key object.
      #
      # Returns an +OpenSSL::PKey::EC+ for EC2 keys, +OpenSSL::PKey::RSA+ for
      # RSA keys, or an Ed25519 key for OKP keys, suitable for use with
      # +OpenSSL::PKey#verify+.
      #
      # Raises +UnsupportedKeyTypeError+ if the key type, algorithm, or curve
      # is not supported.
      def to_openssl_key
        case [ key_type, algorithm ]
        when [ EC2, ES256 ] then build_ec2_es256_key
        when [ OKP, EDDSA ] then build_okp_eddsa_key
        when [ RSA, RS256 ] then build_rsa_rs256_key
        else raise ActionPack::WebAuthn::UnsupportedKeyTypeError, "Unsupported COSE key type/algorithm: #{key_type}/#{algorithm}"
        end
      end

      private
        def build_ec2_es256_key
          curve = parameters[EC2_CURVE_LABEL]
          raise ActionPack::WebAuthn::UnsupportedKeyTypeError, "Unsupported EC curve: #{curve}" unless curve == P256

          x = parameters[EC2_X_LABEL]
          y = parameters[EC2_Y_LABEL]
          raise ActionPack::WebAuthn::InvalidKeyError, "Missing EC2 key coordinates" if x.nil? || y.nil?
          raise ActionPack::WebAuthn::InvalidKeyError, "Invalid EC2 coordinate length" unless x.bytesize == P256_COORDINATE_LENGTH && y.bytesize == P256_COORDINATE_LENGTH

          # Uncompressed point format: 0x04 || x || y
          public_key_bytes = [ UNCOMPRESSED_POINT_MARKER, *x.bytes, *y.bytes ].pack("C*")

          asn1 = OpenSSL::ASN1::Sequence([
            OpenSSL::ASN1::Sequence([
              OpenSSL::ASN1::ObjectId("id-ecPublicKey"),
              OpenSSL::ASN1::ObjectId("prime256v1")
            ]),
            OpenSSL::ASN1::BitString(public_key_bytes)
          ])

          OpenSSL::PKey::EC.new(asn1.to_der)
        rescue OpenSSL::PKey::PKeyError => error
          raise ActionPack::WebAuthn::InvalidKeyError, "Invalid EC2 key: #{error.message}"
        end

        def build_okp_eddsa_key
          curve = parameters[OKP_CURVE_LABEL]
          raise ActionPack::WebAuthn::UnsupportedKeyTypeError, "Unsupported OKP curve: #{curve}" unless curve == ED25519

          x = parameters[OKP_X_LABEL]
          raise ActionPack::WebAuthn::InvalidKeyError, "Missing OKP key coordinate" if x.nil?

          asn1 = OpenSSL::ASN1::Sequence([
            OpenSSL::ASN1::Sequence([
              OpenSSL::ASN1::ObjectId("ED25519")
            ]),
            OpenSSL::ASN1::BitString(x)
          ])

          OpenSSL::PKey.read(asn1.to_der)
        rescue OpenSSL::PKey::PKeyError => error
          raise ActionPack::WebAuthn::InvalidKeyError, "Invalid OKP key: #{error.message}"
        end

        def build_rsa_rs256_key
          n_bytes = parameters[RSA_N_LABEL]
          e_bytes = parameters[RSA_E_LABEL]
          raise ActionPack::WebAuthn::InvalidKeyError, "Missing RSA key parameters" if n_bytes.nil? || e_bytes.nil?
          raise ActionPack::WebAuthn::InvalidKeyError, "RSA key must be at least #{MINIMUM_RSA_KEY_BITS} bits" if n_bytes.bytesize * 8 < MINIMUM_RSA_KEY_BITS

          n = OpenSSL::BN.new(n_bytes, 2)
          e = OpenSSL::BN.new(e_bytes, 2)

          asn1 = OpenSSL::ASN1::Sequence([
            OpenSSL::ASN1::Sequence([
              OpenSSL::ASN1::ObjectId("rsaEncryption"),
              OpenSSL::ASN1::Null.new(nil)
            ]),
            OpenSSL::ASN1::BitString(
              OpenSSL::ASN1::Sequence([
                OpenSSL::ASN1::Integer(n),
                OpenSSL::ASN1::Integer(e)
              ]).to_der
            )
          ])

          OpenSSL::PKey::RSA.new(asn1.to_der)
        rescue OpenSSL::PKey::PKeyError => error
          raise ActionPack::WebAuthn::InvalidKeyError, "Invalid RSA key: #{error.message}"
        end
    end
  end
end
