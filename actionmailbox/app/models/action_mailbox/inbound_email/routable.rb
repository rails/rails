# frozen_string_literal: true

# A newly received +InboundEmail+ will not be routed synchronously as part of ingress controller's receival.
# Instead, the routing will be done asynchronously, using a +RoutingJob+, to ensure maximum parallel capacity.
#
# By default, all newly created +InboundEmail+ records that have the status of +pending+, which is the default,
# will be scheduled for automatic, deferred routing.
module ActionMailbox::InboundEmail::Routable
  extend ActiveSupport::Concern

  included do
    after_create_commit :route_later, if: :pending?
  end

  # Enqueue a +RoutingJob+ for this +InboundEmail+.
  def route_later
    ActionMailbox::RoutingJob.perform_later self
  end

  # Route this +InboundEmail+ using the routing rules declared on the +ApplicationMailbox+.
  def route
    ApplicationMailbox.route self
  end
end
