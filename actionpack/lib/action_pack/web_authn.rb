# frozen_string_literal: true

module ActionPack
  # = Action Pack WebAuthn
  #
  # Provides a pure-Ruby implementation of the WebAuthn (Web Authentication)
  # specification for passkey registration and authentication. This module
  # is the top-level namespace for all WebAuthn components and provides
  # shared utilities used across ceremonies.
  #
  # == Components
  #
  # [ActionPack::WebAuthn::RelyingParty]
  #   Identifies the application to authenticators.
  #
  # [ActionPack::WebAuthn::PublicKeyCredential]
  #   Orchestrates registration and authentication ceremonies.
  #
  # [ActionPack::WebAuthn::Authenticator]
  #   Parses and validates authenticator responses.
  #
  # [ActionPack::WebAuthn::CborDecoder]
  #   Decodes CBOR-encoded data from authenticators.
  #
  # [ActionPack::WebAuthn::CoseKey]
  #   Parses COSE public keys into OpenSSL key objects.
  #
  # == Extending Attestation Formats
  #
  # By default only the "none" attestation format is supported. Register
  # additional verifiers with:
  #
  #   ActionPack::WebAuthn.register_attestation_verifier("packed", MyPackedVerifier.new)
  #
  # == Extending Key Formats
  #
  # By default the ES256, EdDSA, and RS256 COSE key formats are supported.
  # Register additional formats with:
  #
  #   ActionPack::WebAuthn.register_key_format(MyKeyFormat)
  #
  # The format must respond to +algorithm+, +to_public_key_credential_param+,
  # and +build(cose_key)+.
  #
  # == Native App Origins
  #
  # Responses are verified against the request's origin. Native apps assert
  # with a platform origin instead — Android's Credential Manager reports the
  # app's signing certificate as the origin. Allow those origins with:
  #
  #   ActionPack::WebAuthn.allowed_origins = [
  #     "android:apk-key-hash:pNiP5iKyQ8JwgGOaKA1zGPUPJIS-0H1xKCQcfIoGLck"
  #   ]
  #
  module WebAuthn
    extend ActiveSupport::Autoload

    mattr_accessor :challenge_verifier
    mattr_accessor :application_name
    mattr_accessor :relying_party_id
    mattr_accessor :allowed_origins, default: []

    class InvalidResponseError < StandardError; end
    class InvalidCborError < StandardError; end
    class InvalidKeyError < StandardError; end
    class UnsupportedKeyTypeError < StandardError; end
    class InvalidOptionsError < StandardError; end

    autoload :CborDecoder
    autoload :CoseKey
    autoload :Current
    autoload :PublicKeyCredential
    autoload :RelyingParty

    module Authenticator
      extend ActiveSupport::Autoload

      autoload :AssertionResponse
      autoload :Attestation
      autoload :AttestationResponse
      autoload :Data
      autoload :Response

      module AttestationVerifiers
        extend ActiveSupport::Autoload

        autoload :None
      end
    end

    class << self
      # Returns a new RelyingParty configured from the current request context.
      def relying_party
        RelyingParty.new
      end

      # Returns the registry of attestation format verifiers, keyed by format
      # string (e.g., "none", "packed"). Only "none" is registered by default.
      def attestation_verifiers
        @attestation_verifiers ||= {
          "none" => Authenticator::AttestationVerifiers::None.new
        }
      end

      # Registers a custom attestation verifier for the given +format+.
      # The +verifier+ must respond to +verify!(attestation, client_data_json:)+.
      def register_attestation_verifier(format, verifier)
        attestation_verifiers[format.to_s] = verifier
      end

      # Returns the registry of COSE key formats, keyed by COSE algorithm
      # identifier. ES256, EdDSA, and RS256 are registered by default.
      def key_formats
        @key_formats ||= {
          CoseKey::ES256.algorithm => CoseKey::ES256,
          CoseKey::EdDSA.algorithm => CoseKey::EdDSA,
          CoseKey::RS256.algorithm => CoseKey::RS256
        }
      end

      # Registers a custom COSE key format. The +format+ must respond to
      # +algorithm+, +to_public_key_credential_param+, and +build(cose_key)+.
      def register_key_format(format)
        key_formats[format.algorithm] = format
      end
    end
  end
end
