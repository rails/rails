module ActionMailbox::InboundEmail::MessageId
  extend ActiveSupport::Concern

  included do
    before_save :generate_missing_message_id
  end

  module ClassMethods
    def create_and_extract_message_id!(source, **options)
      create! message_id: extract_message_id(source), **options do |inbound_email|
        inbound_email.raw_email.attach io: StringIO.new(source), filename: "message.eml", content_type: "message/rfc822"
      end
    end

    private
      def extract_message_id(source)
        Mail.from_source(source).message_id
      rescue => e
        # FIXME: Add logging with "Couldn't extract Message ID, so will generating a new random ID instead"
      end
  end

  private
    def generate_missing_message_id
      self.message_id ||= Mail::MessageIdField.new.message_id
    end
end
