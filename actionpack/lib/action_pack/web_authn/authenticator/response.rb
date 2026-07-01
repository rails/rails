# frozen_string_literal: true

module ActionPack
  module WebAuthn
    module Authenticator
      # = Action Pack WebAuthn Authenticator Response
      #
      # Abstract base class for WebAuthn authenticator responses. Provides common
      # validation logic for both registration (attestation) and authentication
      # (assertion) ceremonies.
      #
      # This class should not be instantiated directly. Use AttestationResponse for
      # registration or AssertionResponse for authentication.
      #
      # == Validation
      #
      # The +validate!+ method performs security checks required by the WebAuthn
      # specification:
      #
      # * Challenge verification - ensures the response contains a valid, signed challenge
      # * Origin verification - ensures the response comes from the expected origin
      # * User verification - optionally requires biometric or PIN verification
      #
      # == Example
      #
      #   response = ActionPack::WebAuthn::Authenticator::AssertionResponse.new(
      #     client_data_json: client_data_json,
      #     authenticator_data: authenticator_data,
      #     signature: signature,
      #     credential: credential,
      #     origin: "https://example.com",
      #     user_verification: :required
      #   )
      #
      #   response.validate!
      #
      class Response
        include ActiveModel::Validations

        attr_reader :client_data_json
        attr_accessor :origin, :user_verification

        validate :challenge_must_be_present
        validate :challenge_must_not_be_expired
        validate :origin_must_match
        validate :must_not_be_cross_origin
        validate :must_not_have_token_binding
        validate :relying_party_id_must_match
        validate :user_must_be_present
        validate :user_must_be_verified_when_required

        def initialize(client_data_json:, origin: nil, user_verification: :preferred) # :nodoc:
          @client_data_json = client_data_json
          @origin = origin
          @user_verification = user_verification.to_sym
        end

        def validate!
          super
        rescue ActiveModel::ValidationError
          raise ActionPack::WebAuthn::InvalidResponseError, errors.full_messages.join(", ")
        end

        # Returns the RelyingParty used for RP ID validation.
        def relying_party
          ActionPack::WebAuthn.relying_party
        end

        # Parses the client data JSON string into a Hash. Raises
        # +InvalidResponseError+ if the JSON is malformed.
        def client_data
          @client_data ||= JSON.parse(client_data_json)
        rescue JSON::ParserError
          raise ActionPack::WebAuthn::InvalidResponseError, "Client data is not valid JSON"
        end

        def authenticator_data # :nodoc:
          nil
        end

        private
          def challenge_must_be_present
            if client_data["challenge"].blank?
              errors.add(:base, "Challenge missing")
            end
          end

          def challenge_must_not_be_expired
            return if errors.any?

            signed_message = Base64.urlsafe_decode64(client_data["challenge"])

            unless ActionPack::WebAuthn.challenge_verifier.verified(signed_message, purpose: challenge_purpose)
              errors.add(:base, "Challenge has expired")
            end
          rescue ArgumentError
            errors.add(:base, "Challenge is invalid")
          end

          def challenge_purpose
            nil
          end

          def origin_must_match
            if origin.blank?
              errors.add(:base, "Origin missing")
            elsif client_data["origin"].blank?
              errors.add(:base, "Origin missing in client data")
            elsif !ActiveSupport::SecurityUtils.secure_compare(origin.to_s, client_data["origin"].to_s)
              errors.add(:base, "Origin does not match")
            end
          end

          def must_not_be_cross_origin
            if client_data["crossOrigin"] == true
              errors.add(:base, "Cross-origin requests are not supported")
            end
          end

          def must_not_have_token_binding
            if client_data.dig("tokenBinding", "status") == "present"
              errors.add(:base, "Token binding is not supported")
            end
          end

          def relying_party_id_must_match
            unless ActiveSupport::SecurityUtils.secure_compare(
              Digest::SHA256.digest(relying_party.id),
              authenticator_data&.relying_party_id_hash || ""
            )
              errors.add(:base, "Relying party ID does not match")
            end
          end

          def user_must_be_present
            unless authenticator_data&.user_present?
              errors.add(:base, "User presence is required")
            end
          end

          def user_must_be_verified_when_required
            if user_verification == :required && !authenticator_data&.user_verified?
              errors.add(:base, "User verification is required")
            end
          end
      end
    end
  end
end
