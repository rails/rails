require "mail"

module ActionMailbox
  module TestHelper
    # Create an InboundEmail record using an eml fixture in the format of message/rfc822
    # referenced with +fixture_name+ located in +test/fixtures/files/fixture_name+.
    def create_inbound_email_from_fixture(fixture_name, status: :processing)
      create_inbound_email file_fixture(fixture_name), filename: fixture_name, status: status
    end

    def create_inbound_email_from_mail(status: :processing, **mail_options)
      raw_email = Tempfile.new.tap { |raw_email| raw_email.write Mail.new(mail_options).to_s }
      create_inbound_email(raw_email, status: status)
    end

    def create_inbound_email(io, filename: 'mail.eml', status: :processing)
      ActionMailbox::InboundEmail.create_and_extract_message_id! \
        ActionDispatch::Http::UploadedFile.new(tempfile: io, filename: filename, type: 'message/rfc822'),
        status: status
    end

    def receive_inbound_email_from_fixture(*args)
      create_inbound_email_from_fixture(*args).tap(&:route)
    end

    def receive_inbound_email_from_mail(**kwargs)
      create_inbound_email_from_mail(**kwargs).tap(&:route)
    end
  end
end
