module ActionMailroom
  module TestHelper
    # Create an InboundEmail record using an eml fixture in the format of message/rfc822
    # referenced with +fixture_name+ located in +test/fixtures/files/fixture_name+.
    def create_inbound_email(fixture_name)
      ActionMailroom::InboundEmail.create!.tap do |inbound_email|
        inbound_email.raw_email.attach \
          ActiveStorage::Blob.create_after_upload! \
            io: file_fixture(fixture_name).open, filename: fixture_name, content_type: 'message/rfc822'
      end
    end
  end
end
