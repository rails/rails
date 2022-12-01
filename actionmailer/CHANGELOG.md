*   Accept procs for args and params in `assert_enqueued_email_with`

    ```ruby
    assert_enqueued_email_with DeliveryJob, params: -> p { p[:token] =~ /\w+/ } do
      UserMailer.with(token: user.generate_token).email_verification.deliver_later
    end
    ```

    *Max Chernyak*

*   Added `*_deliver` callbacks to `ActionMailer::Base` that wrap mail message delivery.

    Example:

    ```ruby
    class EventsMailer < ApplicationMailer
      after_deliver do
        User.find_by(email: message.to.first).update(email_provider_id: message.message_id, emailed_at: Time.current)
      end
    end
    ```

    *Ben Sheldon*

*   Added `deliver_enqueued_emails` to `ActionMailer::TestHelper`. This method
    delivers all enqueued email jobs.

    Example:

    ```ruby
    def test_deliver_enqueued_emails
      deliver_enqueued_emails do
        ContactMailer.welcome.deliver_later
      end
      assert_emails 1
    end
    ```

    *Andrew Novoselac*

*   The `deliver_later_queue_name` used by the default mailer job can now be
    configured on a per-mailer basis. Previously this was only configurable
    for all mailers via `ActionMailer::Base`.

    Example:

    ```ruby
    class EventsMailer < ApplicationMailer
      self.deliver_later_queue_name = :throttled_mailer
    end
    ```

    *Jeffrey Hardy*

*   Email previews now include an expandable section to show all headers.

    Headers like `Message-ID` for threading or email service provider specific
    features like analytics tags or account metadata can now be viewed directly
    in the mailer preview.

    *Matt Swanson*

*   Default `ActionMailer::Parameterized#params` to an empty `Hash`

    *Sean Doyle*

*   `assert_emails` now returns the emails that were sent.

    This makes it easier to do further analysis on those emails:

    ```ruby
    def test_emails_more_thoroughly
      email = assert_emails 1 do
        ContactMailer.welcome.deliver_now
      end
      assert_email "Hi there", email.subject

      emails = assert_emails 2 do
        ContactMailer.welcome.deliver_now
        ContactMailer.welcome.deliver_later
      end
      assert_email "Hi there", emails.first.subject
    end
    ```

    *Alex Ghiculescu*

*   Added ability to download `.eml` file for the email preview.

    *Igor Kasyanchuk*

*   Support multiple preview paths for mailers.

    Option `config.action_mailer.preview_path` is deprecated in favor of
    `config.action_mailer.preview_paths`. Appending paths to this configuration option
    will cause those paths to be used in the search for mailer previews.

    *fatkodima*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/actionmailer/CHANGELOG.md) for previous changes.
