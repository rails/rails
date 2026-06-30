# frozen_string_literal: true

module ActionPack
  module WebAuthn
    # = Action Pack WebAuthn Public Key Credential Request Options
    #
    # Generates options for the WebAuthn authentication ceremony (using an existing
    # credential). These options are passed to +navigator.credentials.get()+ in
    # the browser to prompt the user to authenticate with a registered authenticator.
    #
    # == Usage
    #
    #   options = ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(
    #     credentials: current_user.webauthn_credentials
    #   )
    #
    #   # Return as JSON for the JavaScript WebAuthn API
    #   render json: { publicKey: options.as_json }
    #
    # == Attributes
    #
    # [+credentials+]
    #   A collection of credential records for the user. Each credential must
    #   respond to +id+ returning the Base64URL-encoded credential ID, and
    #   +transports+ returning an array of transport strings.
    #
    # [+relying_party+]
    #   The relying party (application) configuration. Defaults to
    #   +ActionPack::WebAuthn.relying_party+.
    class PublicKeyCredential::RequestOptions < PublicKeyCredential::Options
      attribute :credentials, default: -> { [] }
      attribute :timeout, default: 5.minutes
      attribute :challenge_purpose, default: "authentication"

      def initialize(attributes = {}) # :nodoc:
        super
        validate!
      end

      # Returns a Hash suitable for JSON serialization and passing to the
      # WebAuthn JavaScript API.
      def as_json(options = {})
        json = {
          challenge: challenge,
          rpId: relying_party.id,
          allowCredentials: credentials.map { |credential| allow_credential_json(credential) },
          userVerification: user_verification.to_s
        }

        json[:timeout] = timeout.in_milliseconds.to_i if timeout

        json.as_json(options)
      end

      private
        def allow_credential_json(credential)
          hash = { type: "public-key", id: credential.id }
          hash[:transports] = credential.transports if credential.transports.any?
          hash
        end
    end
  end
end
