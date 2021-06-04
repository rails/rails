# frozen_string_literal: true

module ActionMailbox
  # Ingests inbound emails from Mailgun. Requires the following parameters:
  #
  # - +body-mime+: The full RFC 822 message
  # - +timestamp+: The current time according to Mailgun as the number of seconds passed since the UNIX epoch
  # - +token+: A randomly-generated, 50-character string
  # - +signature+: A hexadecimal HMAC-SHA256 of the timestamp concatenated with the token, generated using the Mailgun Signing key
  #
  # Authenticates requests by validating their signatures.
  #
  # Returns:
  #
  # - <tt>204 No Content</tt> if an inbound email is successfully recorded and enqueued for routing to the appropriate mailbox
  # - <tt>401 Unauthorized</tt> if the request's signature could not be validated, or if its timestamp is more than 2 minutes old
  # - <tt>404 Not Found</tt> if Action Mailbox is not configured to accept inbound emails from Mailgun
  # - <tt>422 Unprocessable Entity</tt> if the request is missing required parameters
  # - <tt>500 Server Error</tt> if the Mailgun Signing key is missing, or one of the Active Record database,
  #   the Active Storage service, or the Active Job backend is misconfigured or unavailable
  #
  # == Usage
  #
  # 1. Give Action Mailbox your Mailgun Signing key (which you can find under Settings -> Security & Users -> API security in Mailgun)
  #    so it can authenticate requests to the Mailgun ingress.
  #
  #    Use <tt>bin/rails credentials:edit</tt> to add your Signing key to your application's encrypted credentials under
  #    +action_mailbox.mailgun_signing_key+, where Action Mailbox will automatically find it:
  #
  #        action_mailbox:
  #          mailgun_signing_key: ...
  #
  #    Alternatively, provide your Signing key in the +MAILGUN_INGRESS_SIGNING_KEY+ environment variable.
  #
  # 2. Tell Action Mailbox to accept emails from Mailgun:
  #
  #        # config/environments/production.rb
  #        config.action_mailbox.ingress = :mailgun
  #
  # 3. {Configure Mailgun}[https://documentation.mailgun.com/en/latest/user_manual.html#receiving-forwarding-and-storing-messages]
  #    to forward inbound emails to +/rails/action_mailbox/mailgun/inbound_emails/mime+.
  #
  #    If your application lived at <tt>https://example.com</tt>, you would specify the fully-qualified URL
  #    <tt>https://example.com/rails/action_mailbox/mailgun/inbound_emails/mime</tt>.
  class Ingresses::Mailgun::InboundEmailsController < ActionMailbox::BaseController
    before_action :authenticate

    def create
      ActionMailbox::InboundEmail.create_and_extract_message_id! mail
    end

    private
      def mail
        params.require("body-mime").tap do |raw_email|
          raw_email.prepend("X-Original-To: ", params.require(:recipient), "\n") if params.key?(:recipient)
        end
      end

      def authenticate
        head :unauthorized unless authenticated?
      end

      def authenticated?
        if key.present?
          Authenticator.new(
            key:       key,
            timestamp: params.require(:timestamp),
            token:     params.require(:token),
            signature: params.require(:signature)
          ).authenticated?
        else
          raise ArgumentError, <<~MESSAGE.squish
            Missing required Mailgun Signing key. Set action_mailbox.mailgun_signing_key in your application's
            encrypted credentials or provide the MAILGUN_INGRESS_SIGNING_KEY environment variable.
          MESSAGE
        end
      end

      def key
        if Rails.application.credentials.dig(:action_mailbox, :mailgun_api_key)
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            Rails.application.credentials.action_mailbox.api_key is deprecated and will be ignored in Rails 7.0.
            Use Rails.application.credentials.action_mailbox.signing_key instead.
          MSG
          Rails.application.credentials.dig(:action_mailbox, :mailgun_api_key)
        elsif ENV["MAILGUN_INGRESS_API_KEY"]
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            The MAILGUN_INGRESS_API_KEY environment variable is deprecated and will be ignored in Rails 7.0.
            Use MAILGUN_INGRESS_SIGNING_KEY instead.
          MSG
          ENV["MAILGUN_INGRESS_API_KEY"]
        else
          Rails.application.credentials.dig(:action_mailbox, :mailgun_signing_key) || ENV["MAILGUN_INGRESS_SIGNING_KEY"]
        end
      end

      class Authenticator
        attr_reader :key, :timestamp, :token, :signature

        def initialize(key:, timestamp:, token:, signature:)
          @key, @timestamp, @token, @signature = key, Integer(timestamp), token, signature
        end

        def authenticated?
          signed? && recent?
        end

        private
          def signed?
            ActiveSupport::SecurityUtils.secure_compare signature, expected_signature
          end

          # Allow for 2 minutes of drift between Mailgun time and local server time.
          def recent?
            Time.at(timestamp) >= 2.minutes.ago
          end

          def expected_signature
            OpenSSL::HMAC.hexdigest OpenSSL::Digest::SHA256.new, key, "#{timestamp}#{token}"
          end
      end
  end
end
