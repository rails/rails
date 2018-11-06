require "mail"

class ActionMailbox::InboundEmail < ActiveRecord::Base
  self.table_name = "action_mailbox_inbound_emails"

  include Incineratable, MessageId, Routable

  has_one_attached :raw_email
  enum status: %i[ pending processing delivered failed bounced ]

  def mail
    @mail ||= Mail.from_source(source)
  end

  def source
    @source ||= raw_email.download
  end

  def processed?
    delivered? || failed? || bounced?
  end
end
