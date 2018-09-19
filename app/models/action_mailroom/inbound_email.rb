require "mail"

class ActionMailroom::InboundEmail < ActiveRecord::Base
  self.table_name = "action_mailroom_inbound_emails"

  include Incineratable, Routable

  has_one_attached :raw_email
  enum status: %i[ pending processing delivered failed bounced ]

  def mail
    @mail ||= Mail.new(Mail::Utilities.binary_unsafe_to_crlf(raw_email.download))
  end
end
