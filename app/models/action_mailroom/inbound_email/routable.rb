module ActionMailroom::InboundEmail::Routable
  extend ActiveSupport::Concern

  included do
    after_create_commit :route_later, if: ->(r) { r.pending? }
  end

  private
    def route_later
      ActionMailroom::RoutingJob.perform_later self
    end
end
