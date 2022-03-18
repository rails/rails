# frozen_string_literal: true

# The +Message-ID+ as specified by rfc822 is supposed to be a unique identifier for that individual email.
# That makes it an ideal tracking token for debugging and forensics, just like +X-Request-Id+ does for
# web request.
#
# If an inbound email does not, against the rfc822 mandate, specify a Message-ID, one will be generated
# using the approach from <tt>Mail::MessageIdField</tt>.
module ActionMailbox::InboundEmail::MessageId
  extend ActiveSupport::Concern

  class_methods do
    # Create a new +InboundEmail+ from the raw +source+ of the email, which is uploaded as an Active Storage
    # attachment called +raw_email+. Before the upload, extract the Message-ID from the +source+ and set
    # it as an attribute on the new +InboundEmail+.
    def create_and_extract_message_id!(source, **options)
      message_checksum = OpenSSL::Digest::SHA1.hexdigest(source)
      message_id = extract_message_id(source) || generate_missing_message_id(message_checksum)

      create! raw_email: create_and_upload_raw_email!(source),
        message_id: message_id, message_checksum: message_checksum, **options
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    private
      def extract_message_id(source)
        Mail.from_source(source).message_id rescue nil
      end

      def generate_missing_message_id(message_checksum)
        Mail::MessageIdField.new("<#{message_checksum}@#{::Socket.gethostname}.mail>").message_id.tap do |message_id|
          logger.warn "Message-ID couldn't be parsed or is missing. Generated a new Message-ID: #{message_id}"
        end
      end

      def create_and_upload_raw_email!(source)
        ActiveStorage::Blob.create_and_upload! io: StringIO.new(source), filename: "message.eml", content_type: "message/rfc822",
                                               service_name: ActionMailbox.storage_service
      end
  end
end
