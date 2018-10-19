class ActionMailbox::Ingresses::Sendgrid::InboundEmailsController < ActionMailbox::BaseController
  cattr_accessor :username, default: "actionmailbox"
  cattr_accessor :password

  before_action :authenticate

  def create
    ActionMailbox::InboundEmail.create_and_extract_message_id! params.require(:email)
  end
end
