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
  module WebAuthn
    extend ActiveSupport::Autoload

    mattr_accessor :challenge_verifier
    mattr_accessor :application_name

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
    end
  end
end
