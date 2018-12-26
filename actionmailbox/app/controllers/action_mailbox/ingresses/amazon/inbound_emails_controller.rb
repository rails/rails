# frozen_string_literal: true

module ActionMailbox
  # Ingests inbound emails from Amazon's Simple Email Service (SES).
  #
  # Requires the full RFC 822 message in the +content+ parameter. Authenticates requests by validating their signatures.
  #
  # Returns:
  #
  # - <tt>204 No Content</tt> if an inbound email is successfully recorded and enqueued for routing to the appropriate mailbox
  # - <tt>401 Unauthorized</tt> if the request's signature could not be validated
  # - <tt>404 Not Found</tt> if Action Mailbox is not configured to accept inbound emails from SES
  # - <tt>422 Unprocessable Entity</tt> if the request is missing the required +content+ parameter
  # - <tt>500 Server Error</tt> if one of the Active Record database, the Active Storage service, or
  #   the Active Job backend is misconfigured or unavailable
  #
  # == Usage
  #
  # 1. Install the {aws-sdk-sns}[https://rubygems.org/gems/aws-sdk-sns] gem:
  #
  #        # Gemfile
  #        gem "aws-sdk-sns", ">= 1.9.0", require: false
  #
  # 2. Tell Action Mailbox to accept emails from SES:
  #
  #        # config/environments/production.rb
  #        config.action_mailbox.ingress = :amazon
  #
  # 3. {Configure SES}[https://docs.aws.amazon.com/ses/latest/DeveloperGuide/receiving-email-notifications.html]
  #    to deliver emails to your application via POST requests to +/rails/action_mailbox/amazon/inbound_emails+.
  #    If your application lived at <tt>https://example.com</tt>, you would specify the fully-qualified URL
  #    <tt>https://example.com/rails/action_mailbox/amazon/inbound_emails</tt>.
  class Ingresses::Amazon::InboundEmailsController < BaseController
    before_action :authenticate

    cattr_accessor :verifier

    def self.prepare
      self.verifier ||= begin
        require "aws-sdk-sns/message_verifier"
        Aws::SNS::MessageVerifier.new
      end
    end

    def create
      ActionMailbox::InboundEmail.create_and_extract_message_id! params.require(:content)
    end

    private
      def authenticate
        head :unauthorized unless verifier.authentic?(request.body)
      end
  end
end
