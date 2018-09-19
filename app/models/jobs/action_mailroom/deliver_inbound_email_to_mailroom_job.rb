class ActionMailroom::DeliverInboundEmailToMailroomJob < ApplicationJob
  queue_as :rails_action_mailroom_inbound_email

  def perform(inbound_email)
    ActionMailroom::Router.receive inbound_email
  end
end
