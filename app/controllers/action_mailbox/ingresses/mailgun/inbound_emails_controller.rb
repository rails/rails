class ActionMailbox::Ingresses::Mailgun::InboundEmailsController < ActionMailbox::BaseController
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
