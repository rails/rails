module ActionMailroom::InboundEmail::Routable
  extend ActiveSupport::Concern

  included do
    after_create_commit :route_later, if: ->(inbound_email) { inbound_email.pending? }
  end

  def route_later
    ActionMailroom::RoutingJob.perform_later self
  end
end
