# frozen_string_literal: true

module Rails
  class Conductor::ActionMailbox::InboundEmails::SourcesController < Rails::Conductor::BaseController
    def new
    end

    def create
      inbound_email = ActionMailbox::InboundEmail.create_and_extract_message_id! params[:source]
      redirect_to main_app.rails_conductor_inbound_email_url(inbound_email)
    end
  end
end
