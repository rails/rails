class ActionMailbox::RoutingJob < ActiveJob::Base
  queue_as :action_mailbox_routing

  def perform(inbound_email)
    ApplicationMailbox.route inbound_email
  end
end
