## Rails 6.1.0 (December 09, 2020) ##

*   Change default queue name of the deliver (`:mailers`) job to be the job adapter's
    default (`:default`).

    *Rafael Mendonça França*

*   Remove deprecated `ActionMailer::Base.receive` in favor of [Action Mailbox](https://github.com/rails/rails/tree/master/actionmailbox).

    *Rafael Mendonça França*

*   Fix ActionMailer assertions don't work for parameterized mail with legacy delivery job.

    *bogdanvlviv*

*   Added `email_address_with_name` to properly escape addresses with names.

    *Sunny Ripert*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/actionmailer/CHANGELOG.md) for previous changes.
