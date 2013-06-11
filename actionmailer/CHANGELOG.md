## Rails 4.0.0.rc2 (June 11, 2013) ##

*   No changes.


## Rails 4.0.0.rc1 (April 29, 2013) ##

* No changes.


## Rails 4.0.0.beta1 (February 25, 2013) ##

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
