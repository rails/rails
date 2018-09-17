class ActionMailroom::DeliverInboundEmailToMailroomJob < ApplicationJob
  queue_as :action_mailroom_inbound_email

  # Occasional `SSL_read: decryption failed or bad record mac` that resolve on retry
  retry_on OpenSSL::SSL::SSLError

  def perform(inbound_email)
    ApplicationMailbox.receive inbound_email
  end
end
