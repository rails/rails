## Rails 6.0.2.1 (December 18, 2019) ##

*   No changes.


## Rails 6.0.2 (December 13, 2019) ##

*   Fix ActionMailer assertions don't work for parameterized mail with legacy delivery job.

    *bogdanvlviv*


## Rails 6.0.1 (November 5, 2019) ##

*   No changes.


## Rails 6.0.0 (August 16, 2019) ##

*   No changes.


## Rails 6.0.0.rc2 (July 22, 2019) ##

*   No changes.


## Rails 6.0.0.rc1 (April 24, 2019) ##

*   No changes.


## Rails 6.0.0.beta3 (March 11, 2019) ##

*   No changes.


## Rails 6.0.0.beta2 (February 25, 2019) ##

*   No changes.


## Rails 6.0.0.beta1 (January 18, 2019) ##

*   Deprecate `ActionMailer::Base.receive` in favor of [Action Mailbox](https://github.com/rails/rails/tree/master/actionmailbox).

    *George Claghorn*

*   Add `MailDeliveryJob` for delivering both regular and parameterized mail. Deprecate using `DeliveryJob` and `Parameterized::DeliveryJob`.

    *Gannon McGibbon*

*   Fix ActionMailer assertions not working when a Mail defines
    a custom delivery job class

    *Edouard Chin*

*   Mails with multipart `format` blocks with implicit render now also check for
    a template name in options hash instead of only using the action name.

    *Marcus Ilgner*

*   `ActionDispatch::IntegrationTest` includes `ActionMailer::TestHelper` module by default.

    *Ricardo Díaz*

*   Add `perform_deliveries` to a payload of `deliver.action_mailer` notification.

    *Yoshiyuki Kinjo*

*   Change delivery logging message when `perform_deliveries` is false.

    *Yoshiyuki Kinjo*

*   Allow call `assert_enqueued_email_with` with no block.

    Example:
    ```
    def test_email
      ContactMailer.welcome.deliver_later
      assert_enqueued_email_with ContactMailer, :welcome
    end

    def test_email_with_arguments
      ContactMailer.welcome("Hello", "Goodbye").deliver_later
      assert_enqueued_email_with ContactMailer, :welcome, args: ["Hello", "Goodbye"]
    end
    ```

    *bogdanvlviv*

*   Ensure mail gem is eager autoloaded when eager load is true to prevent thread deadlocks.

    *Samuel Cochran*

*   Perform email jobs in `assert_emails`.

    *Gannon McGibbon*

*   Add `Base.unregister_observer`, `Base.unregister_observers`,
    `Base.unregister_interceptor`, `Base.unregister_interceptors`,
    `Base.unregister_preview_interceptor` and `Base.unregister_preview_interceptors`.
    This makes it possible to dynamically add and remove email observers and
    interceptors at runtime in the same way they're registered.

    *Claudio Ortolina*, *Kota Miyake*

*   Rails 6 requires Ruby 2.5.0 or newer.

    *Jeremy Daer*, *Kasper Timm Hansen*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/actionmailer/CHANGELOG.md) for previous changes.
