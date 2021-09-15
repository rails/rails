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
