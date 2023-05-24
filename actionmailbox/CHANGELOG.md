## Rails 7.0.5 (May 24, 2023) ##

*   No changes.


## Rails 7.0.4.3 (March 13, 2023) ##

*   No changes.


## Rails 7.0.4.2 (January 24, 2023) ##

*   No changes.


## Rails 7.0.4.1 (January 17, 2023) ##

*   No changes.


## Rails 7.0.4 (September 09, 2022) ##

*   No changes.


## Rails 7.0.3.1 (July 12, 2022) ##

*   No changes.


## Rails 7.0.3 (May 09, 2022) ##

*   No changes.


## Rails 7.0.2.4 (April 26, 2022) ##

*   No changes.


## Rails 7.0.2.3 (March 08, 2022) ##

*   No changes.


## Rails 7.0.2.2 (February 11, 2022) ##

*   No changes.


## Rails 7.0.2.1 (February 11, 2022) ##

*   No changes.


## Rails 7.0.2 (February 08, 2022) ##

*   No changes.


## Rails 7.0.1 (January 06, 2022) ##

*   No changes.


## Rails 7.0.0 (December 15, 2021) ##

*   No changes.


## Rails 7.0.0.rc3 (December 14, 2021) ##

*   No changes.


## Rails 7.0.0.rc2 (December 14, 2021) ##

*   No changes.

## Rails 7.0.0.rc1 (December 06, 2021) ##

*   Removed deprecated environment variable `MAILGUN_INGRESS_API_KEY`.

    *Rafael Mendonça França*

*   Removed deprecated `Rails.application.credentials.action_mailbox.mailgun_api_key`.

    *Rafael Mendonça França*


## Rails 7.0.0.alpha2 (September 15, 2021) ##

*   No changes.


## Rails 7.0.0.alpha1 (September 15, 2021) ##

*   Add `attachments` to the list of permitted parameters for inbound emails conductor.

    When using the conductor to test inbound emails with attachments, this prevents an
    unpermitted parameter warning in default configurations, and prevents errors for
    applications that set:

    ```ruby
    config.action_controller.action_on_unpermitted_parameters = :raise
    ```

    *David Jones*, *Dana Henke*

*   Add ability to configure ActiveStorage service
    for storing email raw source.

    ```yml
    # config/storage.yml
    incoming_emails:
      service: Disk
      root: /secure/dir/for/emails/only
    ```

    ```ruby
    config.action_mailbox.storage_service = :incoming_emails
    ```

    *Yurii Rashkovskii*

*   Add ability to incinerate an inbound message through the conductor interface.

    *Santiago Bartesaghi*

*   OpenSSL constants are now used for Digest computations.

    *Dirkjan Bussink*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/actionmailbox/CHANGELOG.md) for previous changes.
