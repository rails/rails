module ActionMailbox::InboundEmail::Routable
  extend ActiveSupport::Concern

  included do
    after_create_commit :route_later, if: :pending?
  end

  def route_later
    ActionMailbox::RoutingJob.perform_later self
  end

  def route
    ApplicationMailbox.route self
  end
end
