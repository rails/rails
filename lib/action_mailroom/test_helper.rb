module ActionMailroom
  module TestHelper
    # Create an InboundEmail record using an eml fixture in the format of message/rfc822
    # referenced with +fixture_name+ located in +test/fixtures/files/fixture_name+.
    def create_inbound_email(fixture_name, status: :processing)
      raw_email = ActiveStorage::Blob.create_after_upload! \
            io: file_fixture(fixture_name).open, filename: fixture_name, content_type: 'message/rfc822'

      ActionMailroom::InboundEmail.create!(status: status, raw_email: raw_email)
    end    
  end
end
