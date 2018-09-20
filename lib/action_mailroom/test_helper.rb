module ActionMailroom
  module TestHelper
    # Create an InboundEmail record using an eml fixture in the format of message/rfc822
    # referenced with +fixture_name+ located in +test/fixtures/files/fixture_name+.
    def create_inbound_email_from_fixture(fixture_name, status: :processing)
      create_inbound_email file_fixture(fixture_name).open, filename: fixture_name, status: status
    end    

    def create_inbound_email_from_mail(status: :processing, **mail_options)
      create_inbound_email(StringIO.new(Mail.new(mail_options).to_s), status: status)
    end

    def create_inbound_email(io, filename: 'mail.eml', status: :processing)
      ActionMailroom::InboundEmail.create! status: status, raw_email:
        ActiveStorage::Blob.create_after_upload!(io: io, filename: filename, content_type: 'message/rfc822')
    end
  end
end
