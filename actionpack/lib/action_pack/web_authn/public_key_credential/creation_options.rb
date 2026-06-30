# frozen_string_literal: true

module ActionPack
  module WebAuthn
    # = Action Pack WebAuthn Public Key Credential Creation Options
    #
    # Generates options for the WebAuthn registration ceremony (creating a new
    # credential). These options are passed to +navigator.credentials.create()+ in
    # the browser to prompt the user to register an authenticator.
    #
    # == Usage
    #
    #   options = ActionPack::WebAuthn::PublicKeyCredential::CreationOptions.new(
    #     id: current_user.id,
    #     name: current_user.email,
    #     display_name: current_user.name
    #   )
    #
    #   # Return as JSON for the JavaScript WebAuthn API
    #   render json: { publicKey: options.as_json }
    #
    # == Attributes
    #
    # [+id+]
    #   A unique identifier for the user account. Will be Base64URL-encoded in the
    #   output. This should be an opaque identifier (like a primary key), not
    #   personally identifiable information.
    #
    # [+name+]
    #   A human-readable identifier for the user account, typically an email
    #   address or username. Displayed by the authenticator.
    #
    # [+display_name+]
    #   A human-friendly name for the user, typically their full name. Displayed
    #   by the authenticator during registration.
    #
    # [+relying_party+]
    #   The relying party (application) configuration. Defaults to
    #   +ActionPack::WebAuthn.relying_party+.
    #
    # [+authenticator_attachment+]
    #   Restricts the kind of authenticator the user may register. Either
    #   +"platform"+ (built-in, e.g. Touch ID) or +"cross-platform"+ (roaming,
    #   e.g. a security key). Omitted by default, which allows both.
    #
    # == Supported Algorithms
    #
    # By default, supports ES256 (ECDSA with P-256 and SHA-256), EdDSA
    # (Ed25519), and RS256 (RSASSA-PKCS1-v1_5 with SHA-256), which cover
    # the vast majority of authenticators.
    class PublicKeyCredential::CreationOptions < PublicKeyCredential::Options
      ES256 = { type: "public-key", alg: -7 }.freeze
      EDDSA = { type: "public-key", alg: -8 }.freeze
      RS256 = { type: "public-key", alg: -257 }.freeze
      RESIDENT_KEY_OPTIONS = %i[ preferred required discouraged ].freeze
      ATTESTATION_PREFERENCES = %i[ none indirect direct enterprise ].freeze
      AUTHENTICATOR_ATTACHMENTS = %w[ platform cross-platform ].freeze

      attribute :id
      attribute :name
      attribute :display_name
      attribute :resident_key, default: :required
      attribute :authenticator_attachment
      attribute :exclude_credentials, default: -> { [] }
      attribute :attestation, default: :none
      attribute :timeout, default: 10.minutes
      attribute :challenge_purpose, default: "registration"

      validates :id, :name, :display_name, presence: true
      validates :resident_key, inclusion: { in: RESIDENT_KEY_OPTIONS }
      validates :attestation, inclusion: { in: ATTESTATION_PREFERENCES }
      validates :authenticator_attachment, inclusion: { in: AUTHENTICATOR_ATTACHMENTS }, allow_nil: true

      def initialize(attributes = {}) # :nodoc:
        super
        self.resident_key = resident_key.to_sym
        self.attestation = attestation.to_sym
        self.authenticator_attachment = authenticator_attachment&.to_s
        validate!
      end

      # Returns a Hash suitable for JSON serialization and passing to the
      # WebAuthn JavaScript API.
      def as_json(options = {})
        json = {
          challenge: challenge,
          rp: relying_party.as_json,
          user: {
            id: Base64.urlsafe_encode64(id.to_s, padding: false),
            name: name,
            displayName: display_name
          },
          pubKeyCredParams: [
            ES256,
            EDDSA,
            RS256
          ],
          authenticatorSelection: authenticator_selection_json,
          attestation: attestation.to_s
        }

        json[:timeout] = timeout.in_milliseconds.to_i if timeout

        if exclude_credentials.any?
          json[:excludeCredentials] = exclude_credentials.map { |credential| exclude_credential_json(credential) }
        end

        json.as_json(options)
      end

      private
        def authenticator_selection_json
          json = {
            residentKey: resident_key.to_s,
            requireResidentKey: resident_key == :required,
            userVerification: user_verification.to_s
          }

          json[:authenticatorAttachment] = authenticator_attachment if authenticator_attachment
          json
        end

        def exclude_credential_json(credential)
          hash = { type: "public-key", id: credential.id }
          hash[:transports] = credential.transports if credential.transports.any?
          hash
        end
    end
  end
end
