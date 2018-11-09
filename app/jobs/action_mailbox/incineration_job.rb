class ActionMailbox::IncinerationJob < ActiveJob::Base
  queue_as :action_mailbox_incineration

  discard_on ActiveRecord::RecordNotFound

  def self.schedule(inbound_email)
    set(wait: ActionMailbox.incinerate_after).perform_later(inbound_email)
  end

  def perform(inbound_email)
    inbound_email.incinerate
  end
end
