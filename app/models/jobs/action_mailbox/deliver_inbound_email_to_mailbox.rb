class ActionMailbox::DeliverInboundEmailToMailroomJob < ApplicationJob
  queue_as :action_mailbox_inbound_email

  # Occasional `SSL_read: decryption failed or bad record mac` that resolve on retry
  retry_on OpenSSL::SSL::SSLError

  def perform(inbound_email)
    ApplicationMailbox.receive inbound_email
  end
end
