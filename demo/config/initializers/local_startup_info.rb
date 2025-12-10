puts "[Resend Demo] Webhook: #{ENV.fetch("HOST_URL","http://localhost:3000")}/rails/action_mailbox/resend/inbound_emails"
puts "[Resend Demo] RESEND_WEBHOOK_SECRET present? #{ENV.key?("RESEND_WEBHOOK_SECRET")}" 
puts "[Resend Demo] RESEND_DEMO_TO=#{ENV.fetch("RESEND_DEMO_TO","mail@support.migrately.nl")}" 
