## Rails 4.0.0 (unreleased) ##

* Explicit multipart messages no longer set the order of the MIME parts.
  *Nate Berkopec*

* Do not render views when mail() isn't called.
  Fix #7761

  *Yves Senn*

* Allow delivery method options to be set per mail instance *Aditya Sanghi*

  If your smtp delivery settings are dynamic,
  you can now override settings per mail instance for e.g.

      def my_mailer(user,company)
        mail to: user.email, subject: "Welcome!",
             delivery_method_options: {user_name: company.smtp_user,
                                       password: company.smtp_password}
      end

  This will ensure that your default SMTP settings will be overridden
  by the company specific ones. You only have to override the settings
  that are dynamic and leave the static setting in your environment
  configuration file (e.g. config/environments/production.rb)

* Allow to set default Action Mailer options via `config.action_mailer.default_options=` *Robert Pankowecki*

* Raise an `ActionView::MissingTemplate` exception when no implicit template could be found. *Damien Mathieu*

* Asynchronously send messages via the Rails Queue *Brian Cardarella*

* Allow callbacks to be defined in mailers similar to `ActionController::Base`. You can configure default
  settings, headers, attachments, delivery settings or change delivery using
  `before_filter`, `after_filter` etc. *Justin S. Leitgeb*

Please check [3-2-stable](https://github.com/rails/rails/blob/3-2-stable/actionmailer/CHANGELOG.md) for previous changes.
