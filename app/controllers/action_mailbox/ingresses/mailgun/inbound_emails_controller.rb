class ActionMailbox::Ingresses::Mailgun::InboundEmailsController < ActionMailbox::BaseController
  before_action :ensure_authenticated

  def create
    ActionMailbox::InboundEmail.create_and_extract_message_id! params.require("body-mime")
    head :ok
  end

  private
    def ensure_authenticated
      head :unauthorized unless authenticated?
    end

    def authenticated?
      Authenticator.new(authentication_params).authenticated?
    rescue ArgumentError
      false
    end

    def authentication_params
      params.permit(:timestamp, :token, :signature).to_h.symbolize_keys
    end

    class Authenticator
      cattr_accessor :key

      attr_reader :timestamp, :token, :signature

      def initialize(timestamp:, token:, signature:)
        @timestamp, @token, @signature = timestamp, token, signature
      end

      def authenticated?
        signed? && recent?
      end

      private
        def signed?
          ActiveSupport::SecurityUtils.secure_compare signature, expected_signature
        end

        # Allow for 10 minutes of drift between Mailgun time and local server time.
        def recent?
          time >= 10.minutes.ago
        end

        def expected_signature
          OpenSSL::HMAC.hexdigest OpenSSL::Digest::SHA256.new, key, "#{timestamp}#{token}"
        end

        def time
          Time.at Integer(timestamp)
        end
    end
end
