# frozen_string_literal: true

module ActionPack
  module WebAuthn
    # = Action Pack WebAuthn COSE Key \ES256
    #
    # Builds OpenSSL public keys from COSE ES256 keys (ECDSA with the P-256
    # curve and SHA-256), the most common WebAuthn algorithm. Registered by
    # default in ActionPack::WebAuthn.key_formats.
    module CoseKey::ES256
      KEY_TYPE = 2 # EC2
      ALGORITHM = -7

      # COSE EC2 key labels
      CURVE_LABEL = -1
      X_LABEL = -2
      Y_LABEL = -3

      # COSE EC2 curves
      P256 = 1

      P256_COORDINATE_LENGTH = 32
      UNCOMPRESSED_POINT_MARKER = 0x04

      class << self
        def algorithm
          ALGORITHM
        end

        def to_public_key_credential_param
          { type: "public-key", alg: algorithm }
        end

        def build(cose_key)
          unless cose_key.key_type == KEY_TYPE
            raise ActionPack::WebAuthn::UnsupportedKeyTypeError, "Unsupported COSE key type for ES256: #{cose_key.key_type}"
          end

          curve = cose_key.parameters[CURVE_LABEL]

          unless curve == P256
            raise ActionPack::WebAuthn::UnsupportedKeyTypeError, "Unsupported EC curve: #{curve}"
          end

          x = cose_key.parameters[X_LABEL]
          y = cose_key.parameters[Y_LABEL]

          if x.nil? || y.nil?
            raise ActionPack::WebAuthn::InvalidKeyError, "Missing EC2 key coordinates"
          end

          unless x.bytesize == P256_COORDINATE_LENGTH && y.bytesize == P256_COORDINATE_LENGTH
            raise ActionPack::WebAuthn::InvalidKeyError, "Invalid EC2 coordinate length"
          end

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
      end
    end
  end
end
