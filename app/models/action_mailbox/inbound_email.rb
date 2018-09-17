class ActionMailbox::InboundEmail < ActiveRecord::Base
  self.table_name = "action_mailbox_inbound_email"

  after_create_commit :deliver_to_mailroom_later
  has_one_attached :raw_message

  enum status: %i[ pending processing delivered failed bounced ]

  def mail
    @mail ||= Mail.new(Mail::Utilities.binary_unsafe_to_crlf(raw_message.download))
  end

  private
    def deliver_to_mailroom_later
      ActionMailbox::DeliverInboundEmailToMailroomJob.perform_later self
    end
end
