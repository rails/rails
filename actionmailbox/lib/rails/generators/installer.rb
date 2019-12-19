# frozen_string_literal: true

say "Copying application_mailbox.rb to app/mailboxes"
copy_file "#{__dir__}/mailbox/templates/application_mailbox.rb", "app/mailboxes/application_mailbox.rb"

environment <<~end_of_config, env: "production"
  # Prepare the ingress controller used to receive mail
  # config.action_mailbox.ingress = :relay

end_of_config
