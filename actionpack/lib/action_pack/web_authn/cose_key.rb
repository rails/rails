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
    # Key formats are pluggable: +to_openssl_key+ looks up the format for the
    # key's algorithm in ActionPack::WebAuthn.key_formats. The following
    # formats are registered by default, and additional ones can be added with
    # ActionPack::WebAuthn.register_key_format:
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
      extend ActiveSupport::Autoload

      autoload :ES256
      autoload :EdDSA, "action_pack/web_authn/cose_key/eddsa"
      autoload :RS256

      # COSE key labels
      KEY_TYPE_LABEL = 1
      ALGORITHM_LABEL = 3

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
      # Raises +UnsupportedKeyTypeError+ if no key format is registered for
      # the key's algorithm, or if the key type or curve is not supported by
      # the format.
      def to_openssl_key
        if format = ActionPack::WebAuthn.key_formats[algorithm]
          format.build(self)
        else
          raise ActionPack::WebAuthn::UnsupportedKeyTypeError, "Unsupported COSE algorithm: #{algorithm}"
        end
      end
    end
  end
end
