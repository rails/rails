require "mail"

module ActionMailbox
  module TestHelper
    # Create an InboundEmail record using an eml fixture in the format of message/rfc822
    # referenced with +fixture_name+ located in +test/fixtures/files/fixture_name+.
    def create_inbound_email_from_fixture(fixture_name, status: :processing)
      create_inbound_email_from_source file_fixture(fixture_name).read, status: status
    end

    def create_inbound_email_from_mail(status: :processing, **mail_options)
      create_inbound_email_from_source Mail.new(mail_options).to_s, status: status
    end

    # Create an `InboundEmail` using the raw rfc822 `source` as text.
    def create_inbound_email_from_source(source, status: :processing)
      ActionMailbox::InboundEmail.create_and_extract_message_id! source, status: status
    end

    def receive_inbound_email_from_fixture(*args)
      create_inbound_email_from_fixture(*args).tap(&:route)
    end

    def receive_inbound_email_from_mail(**kwargs)
      create_inbound_email_from_mail(**kwargs).tap(&:route)
    end
    def receive_inbound_email_from_source(**kwargs)
      create_inbound_email_from_source(**kwargs).tap(&:route)
    end
  end
end
