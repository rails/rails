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
