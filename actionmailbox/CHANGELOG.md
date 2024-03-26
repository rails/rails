*   Fix all Action Mailbox database related models to respect
    `ActiveRecord::Base.table_name_prefix` configuration.

    *Chedli Bourguiba*

*   Add Amazon SES/SNS ingress.

    Configure AWS SES inbound emails to store email content in AWS S3 and trigger AWS SNS notifications
    sent as an API endpoint request to the ActionMailbox inbound emails controller, subsequently creating
    an ActionMailbox::InboundEmail database record. Provides SNS subscription confirmation for configured
    SNS topics.

    *Bob Farrell*
    *Chris Ortman*
    *Marco Borromeo*
    *Sarah Sunday*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/actionmailbox/CHANGELOG.md) for previous changes.
