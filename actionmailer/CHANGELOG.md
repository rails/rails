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

*   Remove deprecate `*_path` helpers in email views.

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
