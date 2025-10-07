*   Add structured events for Action Mailer:
    - `action_mailer.delivered`
    - `action_mailer.processed`

    *Gannon McGibbon*

## Rails 8.1.0.beta1 (September 04, 2025) ##

*   Add `deliver_all_later` to enqueue multiple emails at once.

    ```ruby
    user_emails = User.all.map { |user| Notifier.welcome(user) }
    ActionMailer.deliver_all_later(user_emails)

    # use a custom queue
    ActionMailer.deliver_all_later(user_emails, queue: :my_queue)
    ```

    This can greatly reduce the number of round-trips to the queue datastore.
    For queue adapters that do not implement the `enqueue_all` method, we
    fall back to enqueuing email jobs indvidually.

    *fatkodima*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/actionmailer/CHANGELOG.md) for previous changes.
