# frozen_string_literal: true

# :enddoc:

module Rails
  # Incinerating will destroy an email that is due and has already been processed.
  class Conductor::ActionMailbox::IncineratesController < Rails::Conductor::BaseController
    def create
      ActionMailbox::InboundEmail.find(params[:inbound_email_id]).incinerate

      redirect_to main_app.rails_conductor_inbound_emails_url
    end
  end
end
