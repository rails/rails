class ActionMailbox::RoutingJob < ActiveJob::Base
  queue_as { ActionMailbox.queues[:routing] }

  def perform(inbound_email)
    inbound_email.route
  end
end
