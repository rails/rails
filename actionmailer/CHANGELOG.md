## Rails 6.1.7.4 (June 26, 2023) ##

*   No changes.


## Rails 6.1.7.3 (March 13, 2023) ##

*   No changes.


## Rails 6.1.7.2 (January 24, 2023) ##

*   No changes.


## Rails 6.1.7.1 (January 17, 2023) ##

*   No changes.


## Rails 6.1.7 (September 09, 2022) ##

*   No changes.


## Rails 6.1.6.1 (July 12, 2022) ##

*   No changes.


## Rails 6.1.6 (May 09, 2022) ##

*   No changes.


## Rails 6.1.5.1 (April 26, 2022) ##

*   No changes.


## Rails 6.1.5 (March 09, 2022) ##

*   No changes.


## Rails 6.1.4.7 (March 08, 2022) ##

*   No changes.


## Rails 6.1.4.6 (February 11, 2022) ##

*   No changes.


## Rails 6.1.4.5 (February 11, 2022) ##

*   No changes.


## Rails 6.1.4.4 (December 15, 2021) ##

*   No changes.


## Rails 6.1.4.3 (December 14, 2021) ##

*   No changes.


## Rails 6.1.4.2 (December 14, 2021) ##

*   No changes.


## Rails 6.1.4.1 (August 19, 2021) ##

*   No changes.


## Rails 6.1.4 (June 24, 2021) ##

*   No changes.


## Rails 6.1.3.2 (May 05, 2021) ##

*   No changes.


## Rails 6.1.3.1 (March 26, 2021) ##

*   No changes.


## Rails 6.1.3 (February 17, 2021) ##

*   No changes.


## Rails 6.1.2.1 (February 10, 2021) ##

*   No changes.


## Rails 6.1.2 (February 09, 2021) ##

*   No changes.


## Rails 6.1.1 (January 07, 2021) ##

*   Sets default mailer queue to `"default"` in the mail assertions.

    *Paul Keen*


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
