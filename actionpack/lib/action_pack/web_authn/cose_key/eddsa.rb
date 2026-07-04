# frozen_string_literal: true

module ActionPack
  module WebAuthn
    # = Action Pack WebAuthn COSE Key \EdDSA
    #
    # Builds OpenSSL public keys from COSE EdDSA keys (Ed25519 curve),
    # increasingly supported by modern authenticators. Registered by
    # default in ActionPack::WebAuthn.key_formats.
    module CoseKey::EdDSA
      KEY_TYPE = 1 # OKP
      ALGORITHM = -8

      # COSE OKP key labels
      CURVE_LABEL = -1
      X_LABEL = -2

      # COSE OKP curves
      ED25519 = 6

      class << self
        def algorithm
          ALGORITHM
        end

        def to_public_key_credential_param
          { type: "public-key", alg: algorithm }
        end

        def build(cose_key)
          unless cose_key.key_type == KEY_TYPE
            raise ActionPack::WebAuthn::UnsupportedKeyTypeError, "Unsupported COSE key type for EdDSA: #{cose_key.key_type}"
          end

          curve = cose_key.parameters[CURVE_LABEL]
          unless curve == ED25519
            raise ActionPack::WebAuthn::UnsupportedKeyTypeError, "Unsupported OKP curve: #{curve}"
          end

          x = cose_key.parameters[X_LABEL]
          if x.nil?
            raise ActionPack::WebAuthn::InvalidKeyError, "Missing OKP key coordinate"
          end

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
      end
    end
  end
end
