module ActionMailbox::InboundEmail::MessageId
  extend ActiveSupport::Concern

  included do
    before_save :generate_missing_message_id
  end

  module ClassMethods
    def create_and_extract_message_id!(raw_email, **options)
      create! raw_email: raw_email, message_id: extract_message_id(raw_email), **options
    end

    private
      def extract_message_id(raw_email)
        mail_from_source(raw_email.read).message_id
      rescue => e
        # FIXME: Add logging with "Couldn't extract Message ID, so will generating a new random ID instead"
      end
  end

  private
    def generate_missing_message_id
      self.message_id ||= Mail::MessageIdField.new.message_id
    end
end
