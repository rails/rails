## Rails 8.0.0.beta1 (September 26, 2024) ##

*   Add support for multiple databases for Action Mailbox.

    `config.action_mailbox.connects_to = { database: { writing: :primary, reading: :primary_replica } }`

    *Matthew Nguyen*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/actionmailbox/CHANGELOG.md) for previous changes.
