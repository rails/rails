# frozen_string_literal: true

# :enddoc:

module Rails
  # Rerouting will run routing and processing on an email that has already been, or attempted to be, processed.
  class Conductor::ActionMailbox::ReroutesController < Rails::Conductor::BaseController
    def create
      inbound_email = ActionMailbox::InboundEmail.find(params[:inbound_email_id])
      reroute inbound_email

      redirect_to main_app.rails_conductor_inbound_email_url(inbound_email)
    end

    private
      def reroute(inbound_email)
        inbound_email.pending!
        inbound_email.route_later
      end
  end
end
