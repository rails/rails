require "mail"

class ActionMailroom::InboundEmail < ActiveRecord::Base
  include Incineratable

  self.table_name = "action_mailroom_inbound_emails"

  has_one_attached :raw_email

  enum status: %i[ pending processing delivered failed bounced ]

  after_create_commit :deliver_to_mailroom_later, if: ->(r) { r.pending? }


  def mail
    @mail ||= Mail.new(Mail::Utilities.binary_unsafe_to_crlf(raw_email.download))
  end

  private
    def deliver_to_mailroom_later
      ActionMailroom::DeliverInboundEmailToMailroomJob.perform_later self
    end
end
