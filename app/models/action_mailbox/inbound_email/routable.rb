module ActionMailbox::InboundEmail::Routable
  extend ActiveSupport::Concern

  included do
    after_create_commit :route_later, if: ->(inbound_email) { inbound_email.pending? }
  end

  def route_later
    ActionMailbox::RoutingJob.perform_later self
  end

  def route
    ApplicationMailbox.route self
  end
end
