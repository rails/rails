class ActionMailroom::InboundEmail < ActiveRecord::Base
  self.table_name = "action_mailroom_inbound_emails"

  has_one_attached :raw_message

  enum status: %i[ pending processing delivered failed bounced ]

  after_create_commit :deliver_to_mailroom_later


  def mail
    @mail ||= Mail.new(Mail::Utilities.binary_unsafe_to_crlf(raw_message.download))
  end

  private
    def deliver_to_mailroom_later
      ActionMailroom::DeliverInboundEmailToMailroomJob.perform_later self
    end
end
