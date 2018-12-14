say "Copying application_mailbox.rb to app/mailboxes"
copy_file "#{__dir__}/mailboxes/application_mailbox.rb", "app/mailboxes/application_mailbox.rb"

environment "# Prepare the ingress controller used to receive mail\nconfig.action_mailbox.ingress = :amazon\n\n", env: 'production'
