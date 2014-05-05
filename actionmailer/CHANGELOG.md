## Rails 4.0.5 (May 6, 2014) ##

*No changes*


## Rails 4.0.4 (March 14, 2014) ##

*   Calling `mail()` without arguments serves as getter for the current mail
    message and keeps previously set headers.

    Example:

        class MailerWithCallback < ActionMailer::Base
          after_action :a_callback

          def welcome
            mail subject: "subject", to: ["joe@example.com"]
          end

          def a_callback
            mail # => returns the current mail message
          end
        end

    *Yves Senn*


## Rails 4.0.3 (February 18, 2014) ##

*No changes*


## Rails 4.0.2 (December 02, 2013) ##

*No changes*


## Rails 4.0.1 (November 01, 2013) ##

*   Instrument the generation of Action Mailer messages. The time it takes to
    generate a message is written to the log.

*   Invoke mailer defaults as procs only if they are procs, do not convert
    with `to_proc`. That an object is convertible to a proc does not mean it's
    meant to be always used as a proc.

    Fixes #11533.

    *Alex Tsukernik*


## Rails 4.0.0 (June 25, 2013) ##

*   Allow passing interpolations to `#default_i18n_subject`, e.g.:

        # config/locales/en.yml
        en:
          user_mailer:
            welcome:
              subject: 'Hello, %{username}'

        # app/mailers/user_mailer.rb
        class UserMailer < ActionMailer::Base
          def welcome(user)
            mail(subject: default_i18n_subject(username: user.name))
          end
        end

    *Olek Janiszewski*

*   Eager loading made to use relation's `in_clause_length` instead of host's one.
    Fixes #8474.

    *Boris Staal*

*   Explicit multipart messages no longer set the order of the MIME parts.

    *Nate Berkopec*

*   Do not render views when `mail` isn't called. Fixes #7761.

    *Yves Senn*

*   Allow delivery method options to be set per mail instance.

    If your SMTP delivery settings are dynamic, you can now override settings
    per mail instance for e.g.

        def my_mailer(user, company)
          mail to: user.email, subject: "Welcome!",
               delivery_method_options: { user_name: company.smtp_user,
                                          password: company.smtp_password }
        end

    This will ensure that your default SMTP settings will be overridden
    by the company specific ones. You only have to override the settings
    that are dynamic and leave the static setting in your environment
    configuration file (e.g. `config/environments/production.rb`).

    *Aditya Sanghi*

*   Allow to set default Action Mailer options via `config.action_mailer.default_options=`. *Robert Pankowecki*

*   Raise an `ActionView::MissingTemplate` exception when no implicit template could be found. *Damien Mathieu*

*   Allow callbacks to be defined in mailers similar to `ActionController::Base`. You can configure default
    settings, headers, attachments, delivery settings or change delivery using
    `before_filter`, `after_filter`, etc. *Justin S. Leitgeb*

Please check [3-2-stable](https://github.com/rails/rails/blob/3-2-stable/actionmailer/CHANGELOG.md) for previous changes.
