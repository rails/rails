*   Reset `ActionMailer::Base.deliveries` after every test in
    `ActionDispatch::IntegrationTest`.

    *Yves Senn*


## Rails 5.0.0.beta2 (February 01, 2016) ##

*   No changes.


## Rails 5.0.0.beta1 (December 18, 2015) ##

*   `config.force_ssl = true` will set
    `config.action_mailer.default_url_options = { protocol: 'https' }`.

    *Andrew Kampjes*

*   Add `config.action_mailer.deliver_later_queue_name` configuration to set the
    mailer queue name.

    *Chris McGrath*

*   `assert_emails` in block form use the given number as expected value.
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
