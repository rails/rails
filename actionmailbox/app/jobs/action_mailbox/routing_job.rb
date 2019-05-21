# frozen_string_literal: true

module ActionMailbox
  # Routing a new InboundEmail is an asynchronous operation, which allows the ingress controllers to quickly
  # accept new incoming emails without being burdened to hang while they're actually being processed.
  class RoutingJob < ActiveJob::Base
    queue_as { ActionMailbox.queues[:routing] }

    def perform(inbound_email)
      inbound_email.route
    end
  end
end
