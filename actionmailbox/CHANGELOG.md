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
