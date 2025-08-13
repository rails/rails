## Rails 7.1.5.2 (August 13, 2025) ##

*   No changes.


## Rails 7.1.5.1 (December 10, 2024) ##

*   No changes.


## Rails 7.1.5 (October 30, 2024) ##

*   No changes.


## Rails 7.1.4.2 (October 23, 2024) ##

*   Fix NoMethodError in `block_format` helper

    *Michael Leimstaedtner*


## Rails 7.1.4.1 (October 15, 2024) ##

*   Avoid regex backtracking in `block_format` helper

    [CVE-2024-47889]

    *John Hawthorn*


## Rails 7.1.4 (August 22, 2024) ##

*   No changes.


## Rails 7.1.3.4 (June 04, 2024) ##

*   No changes.


## Rails 7.1.3.3 (May 16, 2024) ##

*   No changes.


## Rails 7.1.3.2 (February 21, 2024) ##

*   No changes.


## Rails 7.1.3.1 (February 21, 2024) ##

*   No changes.


## Rails 7.1.3 (January 16, 2024) ##

*   No changes.


## Rails 7.1.2 (November 10, 2023) ##

*   No changes.


## Rails 7.1.1 (October 11, 2023) ##

*   No changes.


## Rails 7.1.0 (October 05, 2023) ##

*   No changes.


## Rails 7.1.0.rc2 (October 01, 2023) ##

*   No changes.


## Rails 7.1.0.rc1 (September 27, 2023) ##

*   Introduce `ActionMailer::FormBuilder`

    Use the `default_form_builder` method in mailers to set the default form builder
    for templates rendered by that mailer. Matches the behaviour in Action Controller.

    *Alex Ghiculescu*


## Rails 7.1.0.beta1 (September 13, 2023) ##

*   Mailers are listed in alphabetical order on the mailer preview page now.

    *Martin Spickermann*

*   Deprecate passing params to `assert_enqueued_email_with` via the `:args`
    kwarg. `assert_enqueued_email_with` now supports a `:params` kwarg, so use
    that to pass params:

    ```ruby
    # BEFORE
    assert_enqueued_email_with MyMailer, :my_method, args: { my_param: "value" }

    # AFTER
    assert_enqueued_email_with MyMailer, :my_method, params: { my_param: "value" }
    ```

    To specify named mailer args as a Hash, wrap the Hash in an array:

    ```ruby
    assert_enqueued_email_with MyMailer, :my_method, args: [{ my_arg: "value" }]
    # OR
    assert_enqueued_email_with MyMailer, :my_method, args: [my_arg: "value"]
    ```

    *Jonathan Hefner*

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

*   Introduce the `capture_emails` test helper.

    Returns all emails that are sent in a block.

    ```ruby
    def test_emails
      emails = capture_emails do
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
