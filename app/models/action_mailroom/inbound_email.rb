require "mail"

# TODO: Add email_message_id to the record extracted from raw_email.message_id to make tracing emails easier
class ActionMailroom::InboundEmail < ActiveRecord::Base
  self.table_name = "action_mailroom_inbound_emails"

  include Incineratable, Routable

  has_one_attached :raw_email
  enum status: %i[ pending processing delivered failed bounced ]

  class << self
    def create_from_raw_email!(raw_email, **options)
      create! raw_email: raw_email, message_id: extract_message_id(raw_email), **options
    end
    
    def mail_from_raw_content(raw_email_content)
      Mail.new(Mail::Utilities.binary_unsafe_to_crlf(raw_email_content.to_s))
    end

    private
      def extract_message_id(raw_email)
        mail_from_raw_content(raw_email.read).message_id
      end
  end

  def mail
    @mail ||= self.class.mail_from_raw_content(raw_email.download)
  end
end
