# frozen_string_literal: true

module ActionPack
  module WebAuthn
    module Authenticator
      # = Action Pack WebAuthn Attestation Response
      #
      # Handles the authenticator response from a WebAuthn registration ceremony.
      # When a user registers a new credential, the authenticator returns an
      # attestation response containing the new public key and credential ID.
      #
      # == Usage
      #
      #   response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      #     client_data_json: params[:response][:clientDataJSON],
      #     attestation_object: params[:response][:attestationObject],
      #     origin: "https://example.com"
      #   )
      #
      #   response.validate!
      #
      #   # Store the credential
      #   credential_id = response.attestation.credential_id
      #   public_key = response.attestation.public_key
      #
      # == Validation
      #
      # In addition to the base Response validations, this class verifies:
      #
      # * The client data type is "webauthn.create"
      # * The attestation format has a registered verifier
      # * The attestation statement passes format-specific verification
      #
      class AttestationResponse < Response
        attr_reader :attestation_object

        validate :client_data_type_must_be_create
        validate :attestation_must_be_valid

        def initialize(attestation_object:, **attributes) # :nodoc:
          super(**attributes)
          @attestation_object = attestation_object
        end

        # Returns the decoded Attestation object, lazily parsed from the raw
        # attestation object bytes.
        def attestation
          @attestation ||= ActionPack::WebAuthn::Authenticator::Attestation.wrap(attestation_object)
        end

        # Returns the authenticator data extracted from the attestation object.
        def authenticator_data
          attestation.authenticator_data
        end

        private
          def challenge_purpose
            "registration"
          end

          def client_data_type_must_be_create
            unless client_data["type"] == "webauthn.create"
              errors.add(:base, "Client data type is not webauthn.create")
            end
          end

          def attestation_must_be_valid
            verifier = ActionPack::WebAuthn.attestation_verifiers[attestation.format]

            if verifier
              verifier.verify!(attestation, client_data_json: client_data_json)
            else
              errors.add(:base, "Unsupported attestation format: #{attestation.format}")
            end
          end
      end
    end
  end
end
