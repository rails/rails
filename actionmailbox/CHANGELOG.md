## Rails 7.1.1 (October 11, 2023) ##

*   No changes.


## Rails 7.1.0 (October 05, 2023) ##

*   No changes.


## Rails 7.1.0.rc2 (October 01, 2023) ##

*   No changes.


## Rails 7.1.0.rc1 (September 27, 2023) ##

*   No changes.


## Rails 7.1.0.beta1 (September 13, 2023) ##

*   Added `bounce_now_with` to send the bounce email without going through a mailer queue.

    *Ronan Limon Duparcmeur*

*   Support configured primary key types in generated migrations.

    *Nishiki Liu*

*   Fixed ingress controllers' ability to accept emails that contain no UTF-8 encoded parts.

    Fixes #46297.

    *Jan Honza Sterba*

*   Add X-Forwarded-To addresses to recipients.

    *Andrew Stewart*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/actionmailbox/CHANGELOG.md) for previous changes.
