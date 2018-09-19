class ActionMailroom::InboundEmail::IncinerationJob < ApplicationJob
  queue_as :action_mailroom_incineration

  def self.schedule(inbound_email)
    set(wait: ActionMailroom::InboundEmail::Incineratable::INCINERATABLE_AFTER).perform_later(inbound_email)
  end

  def perform(inbound_email)
    inbound_email.incinerate
  end
end
