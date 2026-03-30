# frozen_string_literal: true

module ActionPack
  module WebAuthn
    module Authenticator
      # = Action Pack WebAuthn Assertion Response
      #
      # Handles the authenticator response from a WebAuthn authentication ceremony.
      # When a user authenticates with an existing credential, the authenticator
      # returns an assertion response containing a signature that proves possession
      # of the private key.
      #
      # == Usage
      #
      #   # Look up the credential by ID
      #   credential = user.credentials.find_by!(
      #     credential_id: params[:id]
      #   )
      #
      #   response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      #     client_data_json: params[:response][:clientDataJSON],
      #     authenticator_data: params[:response][:authenticatorData],
      #     signature: params[:response][:signature],
      #     credential: credential.to_public_key_credential,
      #     origin: "https://example.com"
      #   )
      #
      #   response.validate!
      #
      # == Validation
      #
      # In addition to the base Response validations, this class verifies:
      #
      # * The client data type is "webauthn.get"
      # * The signature is valid for the credential's public key
      #
      class AssertionResponse < Response
        attr_reader :credential, :authenticator_data, :signature

        validate :client_data_type_must_be_get
        validate :signature_must_be_valid
        validate :sign_count_must_increase

        def initialize(credential:, authenticator_data:, signature:, **attributes) # :nodoc:
          super(**attributes)
          @credential = credential
          @signature = signature
          @signature = Base64.urlsafe_decode64(@signature) unless @signature.encoding == Encoding::BINARY
          @authenticator_data = ActionPack::WebAuthn::Authenticator::Data.wrap(authenticator_data)
        rescue ArgumentError
          raise ActionPack::WebAuthn::InvalidResponseError, "Invalid base64 encoding in signature"
        end

        private
          def challenge_purpose
            "authentication"
          end

          def client_data_type_must_be_get
            unless client_data["type"] == "webauthn.get"
              errors.add(:base, "Client data type is not webauthn.get")
            end
          end

          def signature_must_be_valid
            client_data_hash = Digest::SHA256.digest(client_data_json)
            signed_data = authenticator_data.bytes.pack("C*") + client_data_hash
            digest = credential.public_key.oid == "ED25519" ? nil : "SHA256"

            unless credential.public_key.verify(digest, signature, signed_data)
              errors.add(:base, "Invalid signature")
            end
          rescue OpenSSL::PKey::PKeyError
            errors.add(:base, "Invalid signature")
          end

          def sign_count_must_increase
            unless sign_count_increased?
              errors.add(:base, "Sign count did not increase")
            end
          end

          def sign_count_increased?
            if authenticator_data.sign_count.zero? && credential.sign_count.zero?
              # Some authenticators always return 0 for the sign count, even after multiple authentications.
              # In that case, we have to check that both the stored and returned sign counts are 0,
              # which indicates that the authenticator is likely not updating the sign count.
              true
            else
              authenticator_data.sign_count > credential.sign_count
            end
          end
      end
    end
  end
end
