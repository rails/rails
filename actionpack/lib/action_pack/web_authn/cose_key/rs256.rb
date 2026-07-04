# frozen_string_literal: true

module ActionPack
  module WebAuthn
    # = Action Pack WebAuthn COSE Key \RS256
    #
    # Builds OpenSSL public keys from COSE RS256 keys (RSASSA-PKCS1-v1_5
    # with SHA-256), used by some security keys and platforms. Registered
    # by default in ActionPack::WebAuthn.key_formats.
    module CoseKey::RS256
      KEY_TYPE = 3 # RSA
      ALGORITHM = -257

      # COSE RSA key labels
      N_LABEL = -1
      E_LABEL = -2

      MINIMUM_KEY_BITS = 2048

      class << self
        def algorithm
          ALGORITHM
        end

        def to_public_key_credential_param
          { type: "public-key", alg: algorithm }
        end

        def build(cose_key)
          unless cose_key.key_type == KEY_TYPE
            raise ActionPack::WebAuthn::UnsupportedKeyTypeError, "Unsupported COSE key type for RS256: #{cose_key.key_type}"
          end

          n_bytes = cose_key.parameters[N_LABEL]
          e_bytes = cose_key.parameters[E_LABEL]

          if n_bytes.nil? || e_bytes.nil?
            raise ActionPack::WebAuthn::InvalidKeyError, "Missing RSA key parameters"
          end

          if n_bytes.bytesize * 8 < MINIMUM_KEY_BITS
            raise ActionPack::WebAuthn::InvalidKeyError, "RSA key must be at least #{MINIMUM_KEY_BITS} bits"
          end

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
end
