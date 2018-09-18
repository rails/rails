class ActionMailroom::DeliverInboundEmailToMailroomJob < ApplicationJob
  queue_as :action_mailroom_inbound_email

  def perform(inbound_email)
    ActionMailroom::Router.receive inbound_email
  end
end
