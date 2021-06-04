# frozen_string_literal: true

require "mail"

module ActionMailbox
  # The +InboundEmail+ is an Active Record that keeps a reference to the raw email stored in Active Storage
  # and tracks the status of processing. By default, incoming emails will go through the following lifecycle:
  #
  # * Pending: Just received by one of the ingress controllers and scheduled for routing.
  # * Processing: During active processing, while a specific mailbox is running its #process method.
  # * Delivered: Successfully processed by the specific mailbox.
  # * Failed: An exception was raised during the specific mailbox's execution of the +#process+ method.
  # * Bounced: Rejected processing by the specific mailbox and bounced to sender.
  #
  # Once the +InboundEmail+ has reached the status of being either +delivered+, +failed+, or +bounced+,
  # it'll count as having been +#processed?+. Once processed, the +InboundEmail+ will be scheduled for
  # automatic incineration at a later point.
  #
  # When working with an +InboundEmail+, you'll usually interact with the parsed version of the source,
  # which is available as a +Mail+ object from +#mail+. But you can also access the raw source directly
  # using the +#source+ method.
  #
  # Examples:
  #
  #   inbound_email.mail.from # => 'david@loudthinking.com'
  #   inbound_email.source # Returns the full rfc822 source of the email as text
  class InboundEmail < Record
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
end

ActiveSupport.run_load_hooks :action_mailbox_inbound_email, ActionMailbox::InboundEmail
