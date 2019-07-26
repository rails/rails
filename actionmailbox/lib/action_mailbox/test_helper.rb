# frozen_string_literal: true

require "mail"

module ActionMailbox
  module TestHelper
    # Create an +InboundEmail+ record using an eml fixture in the format of message/rfc822
    # referenced with +fixture_name+ located in +test/fixtures/files/fixture_name+.
    def create_inbound_email_from_fixture(fixture_name, status: :processing)
      create_inbound_email_from_source file_fixture(fixture_name).read, status: status
    end

    # Create an +InboundEmail+ by specifying it using +Mail.new+ options. Example:
    #
    #   create_inbound_email_from_mail(from: "david@loudthinking.com", subject: "Hello!")
    def create_inbound_email_from_mail(status: :processing, **mail_options)
      mail = Mail.new(mail_options)
      # Bcc header is not encoded by default
      mail[:bcc].include_in_headers = true if mail[:bcc]

      create_inbound_email_from_source mail.to_s, status: status
    end

    # Create an +InboundEmail+ using the raw rfc822 +source+ as text.
    def create_inbound_email_from_source(source, status: :processing)
      ActionMailbox::InboundEmail.create_and_extract_message_id! source, status: status
    end


    # Create an +InboundEmail+ from fixture using the same arguments as +create_inbound_email_from_fixture+
    # and immediately route it to processing.
    def receive_inbound_email_from_fixture(*args)
      create_inbound_email_from_fixture(*args).tap(&:route)
    end

    # Create an +InboundEmail+ using the same arguments as +create_inbound_email_from_mail+ and immediately route it to
    # processing.
    def receive_inbound_email_from_mail(**kwargs)
      create_inbound_email_from_mail(**kwargs).tap(&:route)
    end

    # Create an +InboundEmail+ using the same arguments as +create_inbound_email_from_source+ and immediately route it
    # to processing.
    def receive_inbound_email_from_source(*args)
      create_inbound_email_from_source(*args).tap(&:route)
    end
  end
end
