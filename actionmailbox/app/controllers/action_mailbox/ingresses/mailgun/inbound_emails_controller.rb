# frozen_string_literal: true

module ActionMailbox
  # Ingests inbound emails from Mailgun. Requires the following parameters:
  #
  # - +body-mime+: The full RFC 822 message
  # - +timestamp+: The current time according to Mailgun as the number of seconds passed since the UNIX epoch
  # - +token+: A randomly-generated, 50-character string
  # - +signature+: A hexadecimal HMAC-SHA256 of the timestamp concatenated with the token, generated using the Mailgun API key
  #
  # Authenticates requests by validating their signatures.
  #
  # Returns:
  #
  # - <tt>204 No Content</tt> if an inbound email is successfully recorded and enqueued for routing to the appropriate mailbox
  # - <tt>401 Unauthorized</tt> if the request's signature could not be validated, or if its timestamp is more than 2 minutes old
  # - <tt>404 Not Found</tt> if Action Mailbox is not configured to accept inbound emails from Mailgun
  # - <tt>422 Unprocessable Entity</tt> if the request is missing required parameters
  # - <tt>500 Server Error</tt> if the Mailgun API key is missing, or one of the Active Record database,
  #   the Active Storage service, or the Active Job backend is misconfigured or unavailable
  #
  # == Usage
  #
  # 1. Give Action Mailbox your {Mailgun API key}[https://help.mailgun.com/hc/en-us/articles/203380100-Where-can-I-find-my-API-key-and-SMTP-credentials-]
  #    so it can authenticate requests to the Mailgun ingress.
  #
  #    Use <tt>rails credentials:edit</tt> to add your API key to your application's encrypted credentials under
  #    +action_mailbox.mailgun_api_key+, where Action Mailbox will automatically find it:
  #
  #        action_mailbox:
  #          mailgun_api_key: ...
  #
  #    Alternatively, provide your API key in the +MAILGUN_INGRESS_API_KEY+ environment variable.
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
      ActionMailbox::InboundEmail.create_and_extract_message_id! params.require("body-mime")
    end

    private
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
            Missing required Mailgun API key. Set action_mailbox.mailgun_api_key in your application's
            encrypted credentials or provide the MAILGUN_INGRESS_API_KEY environment variable.
          MESSAGE
        end
      end

      def key
        Rails.application.credentials.dig(:action_mailbox, :mailgun_api_key) || ENV["MAILGUN_INGRESS_API_KEY"]
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
