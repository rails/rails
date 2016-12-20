## Rails 5.0.1 (December 21, 2016) ##

*   No changes.


## Rails 5.0.1.rc2 (December 10, 2016) ##

*   No changes.


## Rails 5.0.1.rc1 (December 01, 2016) ##

*   No changes.


## Rails 5.0.0 (June 30, 2016) ##

*   Exception handling: use `rescue_from` to handle exceptions raised by
    mailer actions, by message delivery, and by deferred delivery jobs.

    *Jeremy Daer*

*   Disallow calling `#deliver_later` after making local modifications to
    the message which would be lost when the delivery job is enqueued.

    Prevents a common, hard-to-find bug like:

        message = Notifier.welcome(user, foo)
        message.message_id = my_generated_message_id
        message.deliver_later

    The message_id is silently lost! *Only the mailer arguments are passed
    to the delivery job.*

    This raises an exception now. Make modifications to the message within
    the mailer method instead, or use a custom Active Job to manage delivery
    instead of using #deliver_later.

    *Jeremy Daer*

*   Removes `-t` from default Sendmail arguments to match the underlying
    `Mail::Sendmail` setting.

    *Clayton Liggitt*

*   Add support for fragment caching in Action Mailer views.

    *Stan Lo*

*   Reset `ActionMailer::Base.deliveries` after every test in
    `ActionDispatch::IntegrationTest`.

    *Yves Senn*

*   `config.action_mailer.default_url_options[:protocol]` is now set to `https` if `config.force_ssl` is set to `true`.

    *Andrew Kampjes*

*   Add `config.action_mailer.deliver_later_queue_name` configuration to set the
    mailer queue name.

    *Chris McGrath*

*   `assert_emails` in block form, uses the given number as expected value.
    This makes the error message much easier to understand.

    *Yuji Yaginuma*

*   Add support for inline images in mailer previews by using an interceptor
    class to convert cid: urls in image src attributes to data urls.

    *Andrew White*

*   Mailer preview now uses `url_for` to fix links to emails for apps running on
    a subdirectory.

    *Remo Mueller*

*   Mailer previews no longer crash when the `mail` method wasn't called
    (`NullMail`).

    Fixes #19849.

    *Yves Senn*

*   Make sure labels and values line up in mailer previews.

    *Yves Senn*

*   Add `assert_enqueued_emails` and `assert_no_enqueued_emails`.

    Example:

        def test_emails
          assert_enqueued_emails 2 do
            ContactMailer.welcome.deliver_later
            ContactMailer.welcome.deliver_later
          end
        end

        def test_no_emails
          assert_no_enqueued_emails do
            # No emails enqueued here
          end
        end

    *George Claghorn*

*   Add `_mailer` suffix to mailers created via generator, following the same
    naming convention used in controllers and jobs.

    *Carlos Souza*

*   Remove deprecated `*_path` helpers in email views.

    *Rafael Mendonça França*

*   Remove deprecated `deliver` and `deliver!` methods.

    *claudiob*

*   Template lookup now respects default locale and I18n fallbacks.

    Given the following templates:

        mailer/demo.html.erb
        mailer/demo.en.html.erb
        mailer/demo.pt.html.erb

    Before this change, for a locale that doesn't have its associated file, the
    `mailer/demo.html.erb` would be rendered even if `en` was the default locale.

    Now `mailer/demo.en.html.erb` has precedence over the file without locale.

    Also, it is possible to give a fallback.

        mailer/demo.pt.html.erb
        mailer/demo.pt-BR.html.erb

    So if the locale is `pt-PT`, `mailer/demo.pt.html.erb` will be rendered given
    the right I18n fallback configuration.

    *Rafael Mendonça França*

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/actionmailer/CHANGELOG.md) for previous changes.
