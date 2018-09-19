class ActionMailroom::RoutingJob < ActiveJob::Base
  queue_as :action_mailroom_routing

  def perform(inbound_email)
    ApplicationMailbox.route inbound_email
  end
end
