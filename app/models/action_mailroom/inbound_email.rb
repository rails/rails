require "mail"

class ActionMailroom::InboundEmail < ActiveRecord::Base
  self.table_name = "action_mailroom_inbound_emails"

  include Incineratable, MessageId, Routable

  has_one_attached :raw_email
  enum status: %i[ pending processing delivered failed bounced ]

  def self.mail_from_source(source)
    Mail.new Mail::Utilities.binary_unsafe_to_crlf(source.to_s)
  end

  def mail
    @mail ||= self.class.mail_from_source(source)
  end

  def source
    @source ||= raw_email.download
  end
end
