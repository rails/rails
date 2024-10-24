# frozen_string_literal: true

# :enddoc:

module Rails
  class Conductor::ActionMailbox::InboundEmails::SourcesController < Rails::Conductor::BaseController # :nodoc:
    def new
    end

    def create
      inbound_email = ActionMailbox::InboundEmail.create_and_extract_message_id! params[:source]
      if inbound_email
        redirect_to main_app.rails_conductor_inbound_email_url(inbound_email)
      else
        flash.now[:alert] = "This exact email has already been delivered"
        render :new, status: :unprocessable_entity
      end
    end
  end
end
