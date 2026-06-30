# frozen_string_literal: true

module ActionPack
  module WebAuthn
    module Authenticator
      # = Action Pack WebAuthn Attestation
      #
      # Decodes and represents the attestation object returned by an authenticator
      # during registration. The attestation object is CBOR-encoded and contains
      # the authenticator data along with an optional attestation statement.
      #
      # == Usage
      #
      #   attestation = ActionPack::WebAuthn::Authenticator::Attestation.decode(
      #     attestation_object_bytes
      #   )
      #
      #   attestation.credential_id  # => "abc123..."
      #   attestation.public_key     # => OpenSSL::PKey::EC
      #   attestation.sign_count     # => 0
      #
      # == Attributes
      #
      # [+authenticator_data+]
      #   The parsed Data containing credential information.
      #
      # [+format+]
      #   The attestation statement format (e.g., "none", "packed", "fido-u2f").
      #
      # [+attestation_statement+]
      #   The attestation statement, which may contain a signature from the
      #   authenticator manufacturer. Empty for "none" format.
      #
      # == Delegated Methods
      #
      # The following methods are delegated to +authenticator_data+:
      #
      # * +credential_id+ - Base64URL-encoded credential identifier
      # * +public_key+ - OpenSSL public key object
      # * +public_key_bytes+ - Raw COSE key bytes
      # * +sign_count+ - Signature counter for replay detection
      #
      class Attestation
        attr_reader :authenticator_data, :format, :attestation_statement

        delegate :credential_id, :public_key, :public_key_bytes, :sign_count, :aaguid, :backup_eligible?, :backed_up?, to: :authenticator_data

        # Wraps raw attestation data into an Attestation instance. Accepts an
        # existing Attestation object (returned as-is), a Base64URL-encoded string,
        # or raw binary.
        def self.wrap(data)
          if data.is_a?(self)
            data
          else
            data = Base64.urlsafe_decode64(data) unless data.encoding == Encoding::BINARY
            decode(data)
          end
        rescue ArgumentError
          raise ActionPack::WebAuthn::InvalidResponseError, "Invalid base64 encoding in attestation object"
        end

        # Decodes a CBOR-encoded attestation object into an Attestation instance.
        def self.decode(bytes)
          cbor = ActionPack::WebAuthn::CborDecoder.decode(bytes)

          new(
            authenticator_data: ActionPack::WebAuthn::Authenticator::Data.decode(cbor["authData"]),
            format: cbor["fmt"],
            attestation_statement: cbor["attStmt"]
          )
        end

        def initialize(authenticator_data:, format:, attestation_statement:) # :nodoc:
          @authenticator_data = authenticator_data
          @format = format
          @attestation_statement = attestation_statement
        end
      end
    end
  end
end
