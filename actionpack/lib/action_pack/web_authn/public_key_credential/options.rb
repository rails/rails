# frozen_string_literal: true

module ActionPack
  module WebAuthn
    # = Action Pack WebAuthn Public Key Credential Options
    #
    # Abstract base class for WebAuthn ceremony options. Provides shared
    # attributes and challenge generation for both CreationOptions (registration)
    # and RequestOptions (authentication).
    #
    # This class should not be instantiated directly. Use CreationOptions or
    # RequestOptions instead.
    #
    # == Challenge Generation
    #
    # Each options object generates a signed, expiring challenge via
    # +ActionPack::WebAuthn.challenge_verifier+. The challenge is Base64URL-encoded
    # and includes an embedded timestamp so the server can reject stale challenges.
    #
    # == Attributes
    #
    # [+user_verification+]
    #   Controls whether user verification (biometrics/PIN) is required. One of
    #   +:required+, +:preferred+, or +:discouraged+. Defaults to +:preferred+.
    #
    # [+relying_party+]
    #   The RelyingParty configuration. Defaults to +ActionPack::WebAuthn.relying_party+.
    #
    # [+challenge_expiration+]
    #   How long the challenge remains valid. Defaults vary by ceremony type
    #   (configured in the Railtie).
    #
    class PublicKeyCredential::Options
      include ActiveModel::API
      include ActiveModel::Attributes

      CHALLENGE_LENGTH = 32
      USER_VERIFICATION_OPTIONS = %i[ required preferred discouraged ].freeze

      attribute :user_verification, default: :preferred
      attribute :relying_party, default: -> { ActionPack::WebAuthn.relying_party }
      attribute :challenge_expiration
      attribute :challenge_purpose

      validates :user_verification, inclusion: { in: USER_VERIFICATION_OPTIONS }

      def initialize(attributes = {}) # :nodoc:
        super
        self.user_verification = user_verification.to_sym
      end

      # Validates the options, raising +InvalidOptionsError+ if any are invalid.
      def validate!
        super
      rescue ActiveModel::ValidationError
        raise ActionPack::WebAuthn::InvalidOptionsError, errors.full_messages.to_sentence
      end

      # Returns a human-readable representation of the options.
      def inspect
        attributes_string = attributes.map { |name, value| "#{name}: #{value.inspect}" }.join(", ")
        "#<#{self.class.name} #{attributes_string}>"
      end

      # Returns a Base64URL-encoded signed challenge containing a random nonce and
      # an embedded timestamp. The challenge is generated once and memoized for the
      # lifetime of this object.
      #
      # The timestamp allows the server to reject stale challenges. The expiration
      # window is configurable per-ceremony via
      # +config.action_pack.passkey.registration_challenge_expiration+ and
      # +config.action_pack.passkey.authentication_challenge_expiration+, or per-instance
      # via the +challenge_expiration+ attribute.
      def challenge
        @challenge ||= Base64.urlsafe_encode64(
          ActionPack::WebAuthn.challenge_verifier.generate(
            Base64.strict_encode64(SecureRandom.random_bytes(CHALLENGE_LENGTH)),
            expires_in: challenge_expiration,
            purpose: challenge_purpose
          ),
          padding: false
        )
      end
    end
  end
end
