class ActionMailbox::Ingresses::Mailgun::InboundEmailsController < ActionMailbox::BaseController
  before_action :ensure_authenticated

  def create
    ActionMailbox::InboundEmail.create_and_extract_message_id! params.require("body-mime")
  end

  private
    def ensure_authenticated
      head :unauthorized unless authenticated?
    end

    def authenticated?
      Authenticator.new(
        timestamp: params.require(:timestamp),
        token:     params.require(:token),
        signature: params.require(:signature)
      ).authenticated?
    end

    class Authenticator
      cattr_accessor :key
      attr_reader :timestamp, :token, :signature

      def initialize(timestamp:, token:, signature:)
        @timestamp, @token, @signature = Integer(timestamp), token, signature

        ensure_presence_of_key
      end

      def authenticated?
        signed? && recent?
      end

      private
        def ensure_presence_of_key
          unless key.present?
            raise ArgumentError, "Missing required Mailgun API key"
          end
        end


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
