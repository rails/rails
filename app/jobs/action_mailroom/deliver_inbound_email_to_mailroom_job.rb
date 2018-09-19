class ActionMailroom::DeliverInboundEmailToMailroomJob < ActiveJob::Base
  queue_as :action_mailroom_inbound_email

  def perform(inbound_email)
    ActionMailroom::Mailbox.route inbound_email
  end
end
