class ActionMailbox::Ingresses::Sendgrid::InboundEmailsController < ActionMailbox::BaseController
  before_action :authenticate_by_password

  def create
    ActionMailbox::InboundEmail.create_and_extract_message_id! params.require(:email)
  end
end
