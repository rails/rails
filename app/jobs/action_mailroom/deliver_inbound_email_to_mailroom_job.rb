class ActionMailroom::DeliverInboundEmailToMailroomJob < ActiveJob::Base
  queue_as :action_mailroom_inbound_email

  def perform(inbound_email)
    ApplicationMailbox.route inbound_email
  end
end
