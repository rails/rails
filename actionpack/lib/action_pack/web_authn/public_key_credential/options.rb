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
    # +ActionPack::WebAuthn.challenge_verifier+.
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
    # [+timeout+]
    #   How long the ceremony may take. Sent to the browser as the WebAuthn +timeout+,
    #   and used server-side as the challenge's expiry so it can't outlive the prompt.
    #   Integer values are treated as seconds, +ActiveSupport::Duration+ values
    #   (e.g. `10.minutes`) can also be used.
    #   Defaults to +CreationOptions::DEFAULT_TIMEOUT+ or +RequestOptions::DEFAULT_TIMEOUT+,
    #   depending on ceremony type.
    #
    # [+extensions+]
    #   A Hash of WebAuthn client extension inputs passed through to the
    #   authenticator. Omitted when blank.
    #
    # [+hints+]
    #   An ordered list of hints guiding the browser's authenticator UI, e.g.
    #   "security-key", "client-device", or "hybrid". Omitted when empty.
    #
    class PublicKeyCredential::Options
      include ActiveModel::API
      include ActiveModel::Attributes

      CHALLENGE_LENGTH = 32
      USER_VERIFICATION_OPTIONS = %i[ required preferred discouraged ].freeze

      attribute :user_verification, default: :preferred
      attribute :relying_party, default: -> { ActionPack::WebAuthn.relying_party }
      attribute :timeout
      attribute :extensions
      attribute :hints, default: -> { [] }
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
      # The timestamp allows the server to reject stale challenges. The validity
      # window is configurable per-ceremony via
      # +config.action_pack.passkey.default_registration_options+ and
      # +config.action_pack.passkey.default_authentication_options+, or per-instance via
      # the +timeout+ attribute.
      def challenge
        @challenge ||= Base64.urlsafe_encode64(
          ActionPack::WebAuthn.challenge_verifier.generate(
            Base64.strict_encode64(SecureRandom.random_bytes(CHALLENGE_LENGTH)),
            expires_in: timeout,
            purpose: challenge_purpose
          ),
          padding: false
        )
      end

      # Returns a Hash representation of the options that's suitable for JSON
      # serialization and which can be passed to the WebAuthn JavaScript API.
      def as_json(*)
        json = {}
        json[:timeout] = timeout.in_milliseconds.to_i if timeout
        json[:extensions] = extensions if extensions.present?
        json[:hints] = hints if hints.any?
        json
      end
    end
  end
end
