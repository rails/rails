# frozen_string_literal: true

module ActionMailbox
  # Ingests inbound emails from SendGrid. Requires an +email+ parameter containing a full RFC 822 message.
  #
  # Authenticates requests using HTTP basic access authentication. The username is always +actionmailbox+, and the
  # password is read from the application's encrypted credentials or an environment variable. See the Usage section below.
  #
  # Note that basic authentication is insecure over unencrypted HTTP. An attacker that intercepts cleartext requests to
  # the SendGrid ingress can learn its password. You should only use the SendGrid ingress over HTTPS.
  #
  # Returns:
  #
  # - <tt>204 No Content</tt> if an inbound email is successfully recorded and enqueued for routing to the appropriate mailbox
  # - <tt>401 Unauthorized</tt> if the request's signature could not be validated
  # - <tt>404 Not Found</tt> if Action Mailbox is not configured to accept inbound emails from SendGrid
  # - <tt>422 Unprocessable Entity</tt> if the request is missing the required +email+ parameter
  # - <tt>500 Server Error</tt> if the ingress password is not configured, or if one of the Active Record database,
  #   the Active Storage service, or the Active Job backend is misconfigured or unavailable
  #
  # == Usage
  #
  # 1. Tell Action Mailbox to accept emails from SendGrid:
  #
  #        # config/environments/production.rb
  #        config.action_mailbox.ingress = :sendgrid
  #
  # 2. Generate a strong password that Action Mailbox can use to authenticate requests to the SendGrid ingress.
  #
  #    Use <tt>bin/rails credentials:edit</tt> to add the password to your application's encrypted credentials under
  #    +action_mailbox.ingress_password+, where Action Mailbox will automatically find it:
  #
  #        action_mailbox:
  #          ingress_password: ...
  #
  #    Alternatively, provide the password in the +RAILS_INBOUND_EMAIL_PASSWORD+ environment variable.
  #
  # 3. {Configure SendGrid Inbound Parse}[https://sendgrid.com/docs/for-developers/parsing-email/setting-up-the-inbound-parse-webhook/]
  #    to forward inbound emails to +/rails/action_mailbox/sendgrid/inbound_emails+ with the username +actionmailbox+ and
  #    the password you previously generated. If your application lived at <tt>https://example.com</tt>, you would
  #    configure SendGrid with the following fully-qualified URL:
  #
  #        https://actionmailbox:PASSWORD@example.com/rails/action_mailbox/sendgrid/inbound_emails
  #
  #    *NOTE:* When configuring your SendGrid Inbound Parse webhook, be sure to check the box labeled *"Post the raw,
  #    full MIME message."* Action Mailbox needs the raw MIME message to work.
  class Ingresses::Sendgrid::InboundEmailsController < ActionMailbox::BaseController
    before_action :authenticate_by_password
    param_encoding :create, :email, Encoding::ASCII_8BIT

    def create
      ActionMailbox::InboundEmail.create_and_extract_message_id! mail
    rescue JSON::ParserError => error
      logger.error error.message
      head ActionDispatch::Constants::UNPROCESSABLE_CONTENT
    end

    private
      def mail
        params.require(:email).tap do |raw_email|
          envelope["to"].each { |to| raw_email.prepend("X-Original-To: ", to, "\n") } if params.key?(:envelope)
        end
      end

      def envelope
        JSON.parse(params.require(:envelope))
      end
  end
end
